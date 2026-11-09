' PROBE ONLY. No network transport, account contact or registry access.
sub init()
    m.top.functionName = "fixtureVerify"
end sub

sub fixtureVerify()
    url = m.top.baseUrl
    if m.top.fixtureType = "m3u" then url = m.top.url
    m.top.progress = "Verifying synthetic fixture"
    duration = 150
    if instr(1, url, "slow") > 0 then duration = 5000
    clock = CreateObject("roTimespan")
    clock.mark()
    while clock.totalMilliseconds() < duration
        if m.top.cancelRequested then return
        sleep(25)
    end while
    if instr(1, url, "reject") > 0
        m.top.result = {ok: false, message: "Synthetic rejection"}
        return
    end if
    if m.top.requestIdentity.referer <> "" then stop
    if m.top.requestIdentity.userAgent <> "Fixture-Agent" then stop
    channel = normalizeChannel({id: 1, uuid: "11111111-2222-3333-4444-555555555555", name: "Synthetic", channel_number: "1"})
    result = {ok: true, channels: [channel], groups: [], scope: "fixture", generation: "fixture", accountId: "7", accountUsername: "Viewer", apiKey: "", warning: "", authModeUsed: "x-api-key"}
    if m.top.fixtureType = "dispatcharr"
        if m.top.apiKey = "" and m.top.password = "" then stop
        if m.top.apiKey <> "" and m.top.username <> "" then stop
        result.apiKey = "verified-fixture-key"
    else if m.top.fixtureType = "xtream"
        if m.top.username <> "Viewer" or m.top.password <> "fixture-password" then stop
        result.accountId = "xc-fixture"
    end if
    m.top.result = result
end sub
