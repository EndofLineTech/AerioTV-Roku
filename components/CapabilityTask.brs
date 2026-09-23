sub init()
    m.top.functionName = "refreshCapabilities"
end sub

sub refreshCapabilities()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    accountId = m.top.accountId
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 45000
    user = requestJson(m.base + "/api/accounts/users/me/")
    if type(user) <> "roAssociativeArray"
        finish({ok: false, relogin: httpAccountRejected(m.httpFailure), message: "Could not refresh account permissions. " + m.failure})
        return
    end if
    if textValue(user.id) <> accountId
        finish({ok: false, identityChanged: true, message: "The connected account changed. Reconnect before continuing."})
        return
    end if
    profileRows = apiRows(requestJson(m.base + "/api/core/outputprofiles/"))
    audioProfile = compatibleAacProfile(profileRows)
    profileState = "ready"
    profileMessage = ""
    if profileRows = invalid
        profileState = "error"
        profileMessage = "Could not discover an AAC output profile. " + m.failure
    else if audioProfile = invalid
        profileState = "unavailable"
        profileMessage = "No active copy-video/AAC output profile is available for this account."
    end if
    ' Identity has been verified. Publish this prerequisite before optional
    ' version/settings/channel-fact requests, which may take many pages.
    if m.top.cancelRequested = true
        finish({ok: false})
        return
    end if
    m.top.profileResult = {accountId: accountId, state: profileState, profile: audioProfile, message: profileMessage}
    version = requestJson(m.base + "/api/core/version/")
    settings = requestJson(m.base + "/api/core/settings/")
    capabilities = normalizeCapabilities(user, version, settings, CreateObject("roDateTime").asSeconds())
    user = invalid
    ' Facts supplement the lean summary but do not replace its scoped lineup.
    rows = requestPages("/api/channels/channels/?page=1&page_size=200")
    facts = normalizeChannelCapabilities(rows)
    finish({ok: true, capabilities: capabilities, audioProfile: audioProfile, channelFacts: facts, factsAvailable: rows <> invalid})
end sub

sub finish(result as object)
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested = true then return
    m.top.result = result
end sub
