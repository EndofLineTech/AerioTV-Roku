function livePlaybackDescriptor(baseUrl as string, channel as dynamic) as dynamic
    base = normalizeBaseUrl(baseUrl)
    if base = "" or type(channel) <> "roAssociativeArray" then return invalid
    uuid = textValue(channel.uuid)
    if not CreateObject("roRegex", "^[A-Za-z0-9-]+$", "").isMatch(uuid) then return invalid
    ' Dispatcharr names its output mpegts; Roku's ContentNode enum is ts.
    ' mpegts is rejected as NONE, leaving reader selection to autodetection.
    return {
        url: base + "/proxy/ts/stream/" + uuid + "?output_format=mpegts"
        streamFormat: "ts", live: true
        title: textValue(channel.name), programId: uuid
    }
end function

function playerChannelDirection(key as string, scheme = "apple" as string) as integer
    direction = 0
    if key = "up" then direction = 1
    if key = "down" then direction = -1
    if scheme = "guide" then direction = -direction
    return direction
end function

function playbackTrackChoices(tracks as dynamic, kind as string, selected as string) as object
    choices = []
    if type(tracks) <> "roArray" then return choices
    if kind <> "audio" and kind <> "subtitle" then return choices
    seen = {}
    seen.setModeCaseSensitive()
    for each track in tracks
        if type(track) = "roAssociativeArray"
            id = textValue(track.track)
            title = textValue(track.name)
            if kind = "subtitle"
                id = textValue(track.trackName)
                title = textValue(track.description)
            end if
            if id <> "" and not seen.doesExist(id)
                if title = "" then title = textValue(track.language)
                if title = "" then title = "Track " + (choices.count() + 1).toStr()
                if id = selected then title = "[Selected] " + title
                choices.push({title: title, action: kind, track: id})
                seen[id] = true
            end if
        end if
    end for
    return choices
end function

function adjacentLiveChannel(lineup as object, currentUuid as string, direction as integer) as dynamic
    for i = 0 to lineup.count() - 1
        if lineup[i].uuid = currentUuid
            target = i
            if direction = -1 and i > 0 then target = i - 1
            if direction = 1 and i < lineup.count() - 1 then target = i + 1
            return {channel: lineup[target], changed: target <> i, index: target, count: lineup.count()}
        end if
    end for
    return invalid
end function

function playerBrowserChannels(channels as object, group as string, favorites as object, recent as object, collections = invalid as dynamic) as object
    if left(group, 11) = "collection:" and type(collections) = "roArray"
        for each collection in collections
            if "collection:" + collection.id = group
                index = {}
                for each channel in channels
                    index[channel.id] = channel
                    index[channel.uuid] = channel
                end for
                result = []
                seen = {}
                for each id in collection.channels
                    if index.doesExist(id)
                        channel = index[id]
                        if not seen.doesExist(channel.uuid) then result.push(channel)
                        seen[channel.uuid] = true
                    end if
                end for
                return result
            end if
        end for
        return []
    end if
    if group <> "recent" then return filterChannels(channels, group, favorites)
    byId = {}
    for each channel in channels
        byId[channel.uuid] = channel
    end for
    result = []
    for each id in recent
        if byId.doesExist(id) then result.push(byId[id])
    end for
    return result
end function

function sleepTimerRemaining(deadline as integer, now as integer) as integer
    if deadline <= 0 then return -1
    if now >= deadline then return 0
    return deadline - now
end function

function sleepTimerLabel(deadline as integer, now as integer) as string
    remaining = sleepTimerRemaining(deadline, now)
    if remaining <= 0 then return "Off"
    return ((remaining + 59) \ 60).toStr() + " min remaining"
end function

function sourceVideoStalled(previous as dynamic, current as dynamic) as boolean
    if type(previous) <> "roAssociativeArray" or type(current) <> "roAssociativeArray" then return false
    if previous.audio = invalid or current.audio = invalid or previous.video = invalid or current.video = invalid then return false
    if current.audio <= previous.audio + 0.5 then return false
    return abs(current.video - previous.video) < 0.01
end function

function sanitizePlaybackDiagnostic(detail as string, apiKey = "" as string) as string
    if apiKey <> ""
        offset = instr(1, detail, apiKey)
        while offset > 0
            detail = left(detail, offset - 1) + "[credential]" + mid(detail, offset + len(apiKey))
            ' Continue after the replacement, even if the key matches its text.
            offset = instr(offset + 12, detail, apiKey)
        end while
    end if
    detail = CreateObject("roRegex", "https?://[^\s]+", "i").replaceAll(detail, "[media URL]")
    detail = CreateObject("roRegex", "(authorization|x-api-key)\s*[:=][^\r\n]*", "i").replaceAll(detail, "[credential header]")
    return left(detail, 500)
end function

function nativeStreamDetails(snapshot as dynamic, apiKey = "" as string) as object
    result = {video: "Unavailable", audio: "Unavailable", resolution: "Unavailable", frameRate: "Unavailable", network: "Unavailable", bitrate: "Unavailable", buffering: "Unavailable", rendered: "Unavailable", dropped: "Unavailable", repeated: "Unavailable", errors: "Unavailable"}
    if type(snapshot) <> "roAssociativeArray" then return result
    for each field in [{key: "videoFormat", target: "video"}, {key: "audioFormat", target: "audio"}]
        value = textValue(snapshot[field.key])
        if value <> "" then result[field.target] = sanitizePlaybackDiagnostic(value, apiKey)
    end for
    info = snapshot.streamInfo
    if type(info) = "roAssociativeArray"
        measured = textValue(info.measuredBitrate)
        if CreateObject("roRegex", "^[0-9]+$", "").isMatch(measured)
            if val(measured) > 0 then result.network = measured + " bps (at stream selection)"
        end if
        bitrate = textValue(info.streamBitrate)
        if CreateObject("roRegex", "^[0-9]+$", "").isMatch(bitrate)
            ' Roku's Video field reference does not specify units for this key.
            if val(bitrate) > 0 then result.bitrate = bitrate + " (native value; units unspecified)"
        end if
    end if
    buffer = snapshot.bufferingStatus
    if type(buffer) = "roAssociativeArray"
        percentage = textValue(buffer.percentage)
        if CreateObject("roRegex", "^[0-9]+$", "").isMatch(percentage)
            if val(percentage) <= 100 then result.buffering = percentage + "%"
        end if
    end if
    ' Measured on 3820RW2 / OS 15.3.4 with MPEG-TS: these four native counters
    ' exist, but resolution/videoTrack are empty and tracks is an empty array.
    stats = snapshot.decoderStats
    if type(stats) = "roAssociativeArray"
        for each field in [{key: "renderCount", target: "rendered"}, {key: "frameDropCount", target: "dropped"}, {key: "repeatCount", target: "repeated"}, {key: "streamErrorCount", target: "errors"}]
            count = textValue(stats[field.key])
            if CreateObject("roRegex", "^[0-9]+$", "").isMatch(count) then result[field.target] = count
        end for
    end if
    ' Render counts are not source frame rate. Never use viewport dimensions
    ' or provider metadata as decoded resolution.
    return result
end function

function serverStreamDetails(raw as dynamic, apiKey = "" as string) as object
    result = {resolution: "Unavailable", frameRate: "Unavailable", video: "Unavailable", audio: "Unavailable", pixels: "Unavailable"}
    if type(raw) <> "roAssociativeArray" then return result
    resolution = textValue(raw.resolution)
    if CreateObject("roRegex", "^[0-9]{2,5}x[0-9]{2,5}$", "i").isMatch(resolution) then result.resolution = resolution
    fps = textValue(raw.source_fps)
    if CreateObject("roRegex", "^[0-9]+(\.[0-9]+)?$", "").isMatch(fps)
        if val(fps) > 0 and val(fps) <= 240 then result.frameRate = fps + " fps"
    end if
    for each field in [{key: "video_codec", target: "video"}, {key: "audio_codec", target: "audio"}, {key: "pixel_format", target: "pixels"}]
        value = textValue(raw[field.key])
        if value <> "" then result[field.target] = sanitizePlaybackDiagnostic(value, apiKey)
    end for
    ' Pixel dimensions do not establish display aspect without SAR/DAR.
    ' These fields are upstream/server reports, never native decoder facts.
    return result
end function

function playbackFailureText(code as integer, detail as string) as string
    reason = "The Roku could not play this channel."
    if code = -1 then reason = "The Roku could not read the channel's media response."
    if code = -2 then reason = "The channel request timed out. Check the server and network."
    if code = -5 then reason = "The Roku reported a media playback error."
    if isStartupBufferingStall(code, detail) then reason = "Playback stalled while buffering. Try this channel again."
    if instr(1, lcase(detail), "startup buffering timed out") > 0 then reason = "The channel did not start after one automatic retry. Try again or choose another channel."
    refusal = nativePlaybackRefusal(detail)
    if refusal = "connection-limit" then reason = "The server or provider connection limit was reached. Stop another session before trying again."
    if refusal = "authentication" then reason = "The media request was not authorized. Check the account and server permissions."
    if refusal = "rate-limit" then reason = "The media server is limiting requests. Wait before trying again."
    if instr(1, lcase(detail), "full-content response on a range request") > 0
        reason = "The server returned a continuous stream to a byte-range request. The playback transport is incompatible."
    end if
    message = reason + chr(10) + "Roku error " + code.toStr()
    if detail <> "" then message += chr(10) + detail
    return message
end function

function isStartupBufferingStall(code as integer, detail as string) as boolean
    if code <> -5 then return false
    if nativePlaybackRefusal(detail) <> "" then return false
    return instr(1, lcase(detail), "buffering is stalled") > 0
end function

function nativePlaybackRefusal(detail as string) as string
    text = lcase(detail)
    if instr(1, text, "connection limit") > 0 or instr(1, text, "max connections") > 0 or instr(1, text, "maximum connections") > 0 then return "connection-limit"
    if CreateObject("roRegex", "http[^0-9]{0,24}(401|403)", "i").isMatch(text) then return "authentication"
    if CreateObject("roRegex", "http[^0-9]{0,24}429", "i").isMatch(text) then return "rate-limit"
    return ""
end function
