sub init()
    m.global.addFields({authHeaderMode: "compatible", httpUserAgent: "PrivateProviderAgent", cacheEpoch: "logo-fixture"})
    m.guide = m.top.findNode("guide")
    m.browser = m.top.findNode("browser")
    m.banner = m.top.findNode("banner")
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "checkLogoViews")
    m.fixture = CreateObject("roSGNode", "ChannelLogoFixtureTask")
    m.fixture.observeField("baseUrl", "beginLogoProbe")
    m.fixture.control = "RUN"
    m.phase = "starting"
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
end sub

sub beginLogoProbe(event as object)
    m.base = event.getData()
    m.url = m.base + "/logo.png?token=fixture%2Bvalue&size=100"
    m.contract = CreateObject("roSGNode", "LogoCacheTask")
    m.contract.baseUrl = m.base
    m.contract.apiKey = "private-fixture-key"
    m.contract.prefix = "tmp:/logo-probe-contract"
    m.contract.ids = ["remote-ok", "remote-redirect", "12", "remote-bad", "remote-large", "remote-missing"]
    m.contract.urls = {"remote-ok": m.url, "remote-redirect": m.base + "/redirect", "remote-bad": m.base + "/bad.png", "remote-large": m.base + "/large.png", "remote-missing": m.base + "/missing.png"}
    m.contract.observeField("result", "onLogoContract")
    m.contract.control = "RUN"
end sub

sub onLogoContract(event as object)
    result = event.getData()
    print "[channel-logo-probe] "; formatJson({diagnostic: true, assets: result.assets.count(), failed: result.failed.count(), reasons: result.reasons, counts: m.fixture.counts})
    if result.assets.count() <> 3 or result.failed.count() <> 3 then stop
    if m.contract.urls <> invalid or m.contract.apiKey <> "" then stop
    if m.fixture.counts.authLeaks <> 0 or m.fixture.counts.proxy <> 1 or m.fixture.counts.redirects <> 1 then stop
    print "[channel-logo-probe] bounded-download-and-header-isolation passed"
    rows = []
    for i = 1 to 12
        rows.push({stream_id: i, name: "Synthetic " + i.toStr(), stream_icon: m.url, num: i})
    end for
    lineup = xtreamLiveLineup(rows, [], m.base, "fixture-user", "fixture-password")
    if not lineup.ok then stop
    m.channels = lineup.channels
    prefs = normalizeAccountPreferences({})
    m.guide.config = {channels: lineup.channels, groups: lineup.groups, preferences: prefs, baseUrl: m.base, apiKey: "private-fixture-key", providerType: "xtream", guideUrl: m.base + "/guide.xml", scope: "logo-probe", generation: "fixture", warning: ""}
    m.guide.active = true
    m.phase = "guide-first"
    m.clock.mark()
    m.poll.control = "start"
end sub

function readyLogoPosters(node as object) as integer
    count = 0
    for i = 0 to node.getChildCount() - 1
        child = node.getChild(i)
        if child.visible <> false
            if child.subtype() = "Poster"
                if left(child.uri, 5) = "tmp:/" and child.loadStatus = "ready" then count++
            else
                count += readyLogoPosters(child)
            end if
        end if
    end for
    return count
end function

sub checkLogoViews()
    if m.clock.totalSeconds() > 35 then stop
    if m.phase = "guide-first" and readyLogoPosters(m.guide.findNode("canvas")) >= 6
        print "[channel-logo-probe] guide-first-six-decoded passed"
        m.guide.callFunc("selectPlayingChannel", "xc-12")
        m.guide.callFunc("refreshPresentation")
        m.phase = "guide-later"
    else if m.phase = "guide-later" and readyLogoPosters(m.guide.findNode("canvas")) >= 6
        print "[channel-logo-probe] guide-later-six-decoded passed"
        m.guide.active = false
        m.guide.visible = false
        model = m.guide.callFunc("playerBrowserData")
        model.mode = "channels"
        model.recent = []
        model.historyAccount = "logo-probe"
        model.baseUrl = m.base
        model.apiKey = "private-fixture-key"
        m.browser.model = model
        m.browser.active = true
        m.phase = "browser"
    else if m.phase = "browser" and readyLogoPosters(m.browser.findNode("canvas")) >= 8
        print "[channel-logo-probe] browser-eight-decoded passed"
        m.browser.callFunc("releaseConnection")
        if m.browser.model <> invalid or m.browser.active then stop
        m.banner.visible = true
        m.banner.session = {baseUrl: m.base, apiKey: "private-fixture-key"}
        m.banner.channel = m.channels[0]
        m.banner.now = 1700000000
        m.banner.info = {channelUuid: "xc-1", status: "unavailable", programs: []}
        m.phase = "banner"
    else if m.phase = "banner" and m.banner.findNode("logo").loadStatus = "ready"
        print "[channel-logo-probe] "; formatJson({diagnostic: true, counts: m.fixture.counts})
        if m.fixture.counts.authLeaks <> 0 or m.fixture.counts.exactQuery < 3 then stop
        if left(m.banner.findNode("logo").uri, 5) <> "tmp:/" then stop
        print "[channel-logo-probe] banner-decoded passed"
        print "[channel-logo-probe] "; formatJson({passed: true, remoteRequests: m.fixture.counts.remote, proxyRequests: m.fixture.counts.proxy, authLeaks: m.fixture.counts.authLeaks})
        m.poll.control = "stop"
        m.fixture.cancelRequested = true
        m.phase = "done"
    end if
end sub
