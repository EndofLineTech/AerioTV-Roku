sub main()
    entry = normalizeConnectionEntry({id: "xtream", name: "Panel", provider: "xtream", url: "https://panel.example.test/prefix", epgUrl: "https://guide.example.test/feed.xml"})
    m.registry = {
        values: {}
        read: function(key as string) as string
            return textValue(m.values[key])
        end function
        write: function(key as string, value as string) as boolean
            m.values[key] = value
            return true
        end function
        flush: function() as boolean
            return true
        end function
    }
    check(saveConnectionStore(m.registry, {schema: 1, selected: entry.id, entries: [entry]}), "persist roster")
    m.connectionStore = loadConnectionStore(m.registry)
    m.selectedConnectionId = entry.id
    m.global = {}
    m.guide = {}
    m.vod = {}
    m.banner = {}
    m.screen = {}
    m.reminderClock = {}
    m.capabilities = {}
    m.connectionElapsed = CreateObject("roTimespan")
    m.preferenceStore = defaultPreferenceStore()
    panelGuide = xtreamGuideUrl(entry.url, "viewer", "fixture-password")
    channels = [{id: "xc-1", uuid: "xc-1", number: "101", tvgId: "Station.alpha", streamId: "1", archiveDays: 7}]
    result = {channels: channels, groups: [], baseUrl: entry.url, liveFormat: "m3u8", timezone: "UTC", guideUrl: panelGuide, scope: "panel-scope", generation: "lineup", accountId: "xc-account"}
    now = uiNow()
    bucket = preferenceScope(connectionPreferenceIdentity(entry, result.accountId))
    m.preferenceStore.accounts[bucket] = {archiveBookmarks: [
        {channelUuid: "xc-1", startsAt: now - 3600, endsAt: now - 1800, position: 120, expiresAt: now + 86400}
        {channelUuid: "xc-2", startsAt: now - 3600, endsAt: now - 1800, position: 120, expiresAt: now + 86400}
    ]}

    ' Completion consumes the selected, saved slot after initial verification.
    m.phoneCommittedId = entry.id
    completeDirectConnection(result, m.connectionStore.entries[0], "viewer", "fixture-password")
    config = m.guide.config
    check(m.xcLiveFormat = "m3u8", "verified Live format applies to the active Xtream session")
    check(instr(1, FormatJson(m.registry.values), "m3u8") = 0, "Live format stays out of persisted metadata")
    check(config.guideUrl = entry.epgUrl and config.baseUrl = entry.url and config.apiKey = "", "verified guide uses saved override; panel base and auth remain separate")
    check(m.banner.session.baseUrl = urlOrigin(entry.url), "live playback still points at the account origin")
    check(m.guide.catchupPermission = "allowed" and config.preferences.archiveBookmarks.count() = 1 and config.preferences.archiveBookmarks[0].channelUuid = "xc-1" and config.preferences.archiveBookmarks[0].position = 120, "override preserves valid archive progress and prunes missing channels")
    check(instr(1, FormatJson(config), "fixture-password") = 0 and instr(1, FormatJson(m.registry.values), "fixture-password") = 0, "override config and persisted metadata never contain the XC password")

    m.providerType = config.providerType
    m.guideUrl = config.guideUrl
    m.lineupGeneration = config.generation
    m.channels = config.channels
    loadMappings()
    overrideGeneration = m.cacheGeneration
    check(overrideGeneration <> config.generation and instr(1, overrideGeneration, config.guideUrl) = 0, "override gets its own digested guide cache identity")
    check(m.channels[0].epgKey = "Station.alpha" and m.allowedKeys.doesExist("Station.alpha") and not m.allowedKeys.doesExist("101"), "override retains Xtream channel-to-XMLTV IDs rather than channel numbers")
    start = guideEpoch("2026-09-23T18:00:00Z")
    guide = xmltvWindowState(start, start + 10800, m.allowedKeys)
    xmltvConsumeChunk(guide, "<programme start=""20260923183000 +0000"" stop=""20260923190000 +0000"" channel=""Station.alpha""><title>Override programme</title></programme>")
    xmltvConsumeChunk(guide, "<programme start=""20260923183000 +0000"" stop=""20260923190000 +0000"" channel=""101""><title>Wrong channel ID</title></programme>")
    check(guide.count = 1 and guide.index[m.channels[0].epgKey][0].title = "Override programme", "XMLTV parser yields only the programme mapped to the lineup")

    ' Completion callback of the Refresh Guide cache clear triggers a reload
    ' using the same source and its generation; no MappingTask is needed.
    m.top = {active: false}
    m.cacheClearTask = {
        isSameNode: function(node as object) as boolean
            return true
        end function
        unobserveField: sub(field as string)
        end sub
    }
    onStoredCacheCleared({getRoSGNode: function() as object
        return {}
    end function})
    check(m.guideUrl = entry.epgUrl and m.cacheGeneration = overrideGeneration and m.scheduled = 2, "manual guide refresh reuses the active override")
    m.guideUrl = "https://other.example.test/feed.xml"
    loadMappings()
    check(m.cacheGeneration <> overrideGeneration, "changing the override invalidates cached windows for the old URL")

    m.connectionStore = connectionStoreUpdate(m.connectionStore, entry.id, {epgUrl: ""})
    m.phoneCommittedId = entry.id
    completeDirectConnection(result, m.connectionStore.entries[0], "viewer", "fixture-password")
    check(m.guideUrl = "" and m.guide.config.guideUrl = panelGuide, "blank override uses the account guide only in the runtime config")
    m.guideUrl = m.guide.config.guideUrl
    loadMappings()
    check(m.cacheGeneration = config.generation and m.cacheGeneration <> overrideGeneration, "account guide keeps its own cache identity without hashing credentials")
    applySelectedConnection()
    check(m.xcLiveFormat = "" and m.xcPassword = "", "selection clears the previous Xtream Live format and credentials")
    print "ALL TESTS PASSED"
end sub

sub scheduleLoad()
    if m.scheduled = invalid then m.scheduled = 0
    m.scheduled++
end sub

' Host brs does not implement Roku's roEVPDigest or roByteArray.fromAsciiString.
function metadataCacheDigest(value as string) as string
    return m3uChannelId(value)
end function

function takePhoneSetupPreferences(preferences as object, entry as object) as object
    return preferences
end function

function persistAccountPreferences() as boolean
    m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
    return true
end function

sub signalStartupComplete()
end sub

sub recordDiagnostic(stage, code, message, elapsed)
end sub

sub check(passed as boolean, label as string)
    if not passed then print "FAIL: "; label : stop
end sub
