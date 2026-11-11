' Preparation only: callers must verify the chosen identity with the provider
' before matching/committing. Never infer server permissions from profile roles.
function phoneSetupEffectiveCredential(payload as object) as dynamic
    chosen = payload.playlist.credential
    if chosen = invalid
        profiles = payload.profiles
        if type(profiles) <> "roArray" then return invalid
        defaultProfile = invalid
        for each profile in profiles
            if profile.isDefault = true
                if defaultProfile <> invalid then return invalid
                defaultProfile = profile
            end if
        end for
        if defaultProfile = invalid and profiles.count() = 1 then defaultProfile = profiles[0]
        if defaultProfile = invalid then return invalid
        chosen = defaultProfile.credential
    end if
    validated = phoneSetupCredential(chosen)
    if validated = invalid then return invalid
    result = {apiKey: "", username: "", password: ""}
    result.append(validated)
    return result
end function

function phoneSetupPrepareImport(payload as object, id as string, digest as string) as object
    failure = {ok: false, message: "These playlist settings cannot be imported. Use manual setup or edit the sending playlist."}
    playlist = payload.playlist
    credential = phoneSetupEffectiveCredential(payload)
    if playlist.type = "m3u" then credential = {apiKey: "", username: "", password: ""}
    if credential = invalid then return {ok: false, message: "Choose one default credential on the sending device, then send setup again."}
    if playlist.type = "dispatcharr"
        if credential.apiKey = "" and (credential.username = "" or credential.password = "") then return failure
    else if playlist.type = "xtream"
        if not xtreamCredentialsValid(credential.username, credential.password) then return failure
    end if
    url = normalizeBaseUrl(playlist.url)
    sessionUrl = false
    if playlist.type = "m3u"
        url = m3uStreamUrl(playlist.url)
        sessionUrl = instr(1, url, "?") > 0 or len(url) > 256
    end if
    if url = "" then return failure
    storedUrl = url
    if sessionUrl then storedUrl = ""
    epg = textValue(playlist.xmltvUrl)
    if epg <> "" and normalizeBaseUrl(epg) = "" then return {ok: false, message: "This XMLTV URL is not supported by this build. Edit it on the sending device and send setup again. Saved connections were not changed."}
    days = int(playlist.guideDays)
    offset = playlist.catchupOffsetMinutes
    if GetInterface(offset, "ifInt") = invalid
        if abs(offset) > 16777215 then return failure
        offset = int(offset)
    end if
    entry = normalizeConnectionEntry({id: id, name: playlist.name, provider: playlist.type, url: storedUrl, epgUrl: epg
        localUrl: textValue(playlist.localUrl), userAgent: textValue(playlist.userAgent), guideDays: days
        catchupOffsetMinutes: offset, vodEnabled: playlist.vodEnabled, channelProfileIds: playlist.channelProfileIds
        sourceDigest: digest, sessionUrl: sessionUrl, remember: playlist.type = "dispatcharr"})
    if entry = invalid then return failure
    notes = []
    if payload.profiles.count() > 0 then notes.push("Household profiles and PINs will not be imported.")
    if payload.sync <> invalid then notes.push("Dispatcharr Sync will not be enabled.")
    if sessionUrl then notes.push("The token-bearing or long playlist URL is session-only; send it again after restarting the app.")
    if entry.localUrl <> "" then notes.push("Local URL retained; automatic LAN failover is not applied by this build.")
    if days <> 1 and days <> 3 and days <> 7 and days <> 14 then notes.push("Guide Days retained but not applied; this build supports 1, 3, 7 or 14 days.")
    if offset <> 0 then notes.push("Catch-up offset retained but not applied by this build.")
    if entry.provider <> "dispatcharr" and entry.channelProfileIds.count() > 0 then notes.push("Channel Profile IDs are retained but only applied to Dispatcharr sources.")
    if entry.provider = "xtream" and epg <> "" then notes.push("Xtream uses its account guide; the supplied XMLTV override is not applied.")
    return {ok: true, entry: entry, url: url, credential: credential, notes: notes}
end function

function phoneSetupVerifiedImport(prepared as object, result as dynamic) as object
    failure = {ok: false, message: "Could not verify the playlist or its live channels. Saved connections were not changed."}
    if type(result) <> "roAssociativeArray" then return failure
    if result.ok <> true or type(result.channels) <> "roArray" then return failure
    if result.channels.count() = 0 then return failure
    verified = copyJson(prepared)
    if verified.entry.provider = "dispatcharr"
        if textValue(result.apiKey) = "" or textValue(result.accountId) = "" then return failure
        verified.entry.accountId = result.accountId
        verified.entry.accountUsername = textValue(result.accountUsername)
        verified.entry.authMode = dispatcharrHeaderMode(textValue(result.authModeUsed))
    else if verified.entry.provider = "xtream"
        verified.entry.accountUsername = verified.credential.username
    end if
    verified.entry = normalizeConnectionEntry(verified.entry)
    if verified.entry = invalid then return failure
    if verified.entry.provider = "dispatcharr" and verified.entry.accountId = "" then return failure
    return verified
end function

function phoneSetupFeedIdentity(url as string) as string
    url = m3uStreamUrl(url)
    if url = "" then return ""
    origin = urlOrigin(url)
    suffix = mid(url, len(origin) + 1)
    if suffix = "" or left(suffix, 1) = "?" then suffix = "/" + suffix
    return phoneSetupServerIdentity(origin) + suffix
end function

function phoneSetupImportedPreferences(preferences as object, entry as object) as object
    result = copyJson(preferences)
    result.vodEnabled = entry.vodEnabled
    days = entry.guideDays
    if days = 1 or days = 3 or days = 7 or days = 14 then result.guide.futureDays = days
    return result
end function

' Fixed, non-sensitive disclosure text; never include a URL/account/credential.
' New imports show these in Diagnostics without another confirmation step.
function phoneSetupImportNotices(prepared as object) as object
    result = []
    if prepared.entry.provider = "dispatcharr" then result.push("The verified API key is saved on this Roku.")
    if prepared.entry.provider = "xtream" then result.push("Xtream credentials are session-only; send them again after restarting.")
    for each note in prepared.notes
        result.push(note)
    end for
    return result
end function

' Stage a verified candidate only; registry/credential persistence is a separate
' transaction owned by the future apply controller. No input object is changed.
function phoneSetupStageVerifiedConnection(store as object, candidate as object, choice as string, matchedId as string) as dynamic
    if store.readOnly = true or choice = "cancel" then return invalid
    staged = normalizeConnectionStore(store)
    if staged.readOnly = true then return invalid
    entry = normalizeConnectionEntry(candidate)
    if entry = invalid then return invalid
    matches = phoneSetupDuplicateIds(staged, entry)
    if choice = "replace"
        matched = false
        for each id in matches
            if id = matchedId then matched = true
        end for
        if not matched then return invalid
        for i = 0 to staged.entries.count() - 1
            if staged.entries[i].id = matchedId
                entry.id = matchedId
                staged.entries[i] = entry
                staged.selected = matchedId
                return staged
            end if
        end for
        return invalid
    end if
    if choice <> "add" and choice <> "addAnyway" then return invalid
    if choice = "add" and matches.count() > 0 then return invalid
    if staged.entries.count() >= 4 or connectionStoreEntry(staged, entry.id) <> invalid then return invalid
    staged.entries.push(entry)
    staged.selected = entry.id
    return staged
end function

function phoneSetupServerIdentity(url as string) as string
    base = normalizeBaseUrl(url)
    if base = "" then return ""
    parts = CreateObject("roRegex", "^(https?)://([^/]+)(.*)$", "i").match(base)
    if parts.count() <> 4 then return ""
    scheme = lcase(parts[1])
    authority = lcase(parts[2])
    if scheme = "https" and right(authority, 4) = ":443" then authority = left(authority, len(authority) - 4)
    if scheme = "http" and right(authority, 3) = ":80" then authority = left(authority, len(authority) - 3)
    return scheme + "://" + authority + parts[3]
end function

function phoneSetupDuplicateIds(store as object, candidate as object) as object
    result = []
    for each entry in store.entries
        if entry.provider = candidate.provider
            matches = false
            if candidate.provider = "m3u"
                digest = textValue(candidate.sourceDigest)
                if digest <> "" and textValue(entry.sourceDigest) = digest then matches = true
                if (digest = "" or textValue(entry.sourceDigest) = "") and candidate.sessionUrl <> true and entry.sessionUrl <> true
                    url = phoneSetupFeedIdentity(textValue(candidate.url))
                    if url <> "" and url = phoneSetupFeedIdentity(textValue(entry.url)) then matches = true
                end if
            else
                url = phoneSetupServerIdentity(textValue(candidate.url))
                if url <> "" and url = phoneSetupServerIdentity(textValue(entry.url))
                    account = textValue(candidate.accountId)
                    savedAccount = textValue(entry.accountId)
                    if candidate.provider = "dispatcharr" and account <> "" and savedAccount <> ""
                        matches = account = savedAccount
                    else
                        username = textValue(candidate.accountUsername)
                        matches = username <> "" and username = textValue(entry.accountUsername)
                    end if
                end if
            end if
            if matches then result.push(entry.id)
        end if
    end for
    return result
end function
