"""Private live Dispatcharr overlay probe; isolated registry and exact restore."""
import importlib.util
import os
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("normal", root / "scripts/test-phone-setup-normal-native.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
original = runner.build
stale_airing = os.environ.get("AERIO_PROBE_STALE_AIRING") == "1"


def build(path, *args, **kwargs):
    intermediate = path.with_suffix(".intermediate.zip")
    original(intermediate, *args, **kwargs)
    with zipfile.ZipFile(intermediate) as source, zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as target:
        for name in source.namelist():
            data = source.read(name)
            if name == "components/AerioScene.brs":
                anchor = b'    else if phase = 9\n'
                assert data.count(anchor) == 1
                data = data.replace(anchor, anchor + b'        if m.overlayClock <> invalid then validateLiveOverlays() : return\n')
                anchor = b'        finishPhoneNormalProbe(passed, "complete")'
                assert data.count(anchor) == 1
                data = data.replace(anchor, b'''        if not passed then finishPhoneNormalProbe(false, "profile") : return
        m.overlayClock = CreateObject("roTimespan")
        m.overlayClock.mark()
        m.overlayStage = 0
        validateLiveOverlays()''')
                data += b'''
sub validateLiveOverlays()
    if m.overlayClock.totalMilliseconds() > 75000
        print "[setup-phone-normal] "; FormatJson({kind: "overlay-timeout", video_state: m.video.state, pending: m.pendingChannel <> invalid})
        finishPhoneNormalProbe(false, "overlay-timeout-" + m.overlayStage.toStr())
        return
    end if
    if m.overlayStage = 0
        facts = m.guide.callFunc("probeLiveProgramDetails")
        if not facts.sampled and m.overlayClock.totalMilliseconds() < 12000 then return
        print "[setup-phone-normal] "; FormatJson({kind: "live-program-details", sampled: facts.sampled, has_art: facts.hasArt, poster_status: facts.status, recovered: facts.recovered = true})
        model = m.guide.callFunc("playerBrowserData")
        if model.channels.count() = 0 then finishPhoneNormalProbe(false, "no-live-channel") : return
        m.devicePreferences.appearanceMode = "light"
        applyDevicePreferences()
        print "[setup-phone-normal] "; FormatJson(m.guide.callFunc("probeLiveGuideGroups"))
        startPlayback(model.channels[0])
        m.overlayStage = 1
    else if m.overlayStage = 1
        if m.video.state <> "playing" or m.pendingChannel <> invalid then return
        hideBanner()
        togglePlayerInfo()
        m.overlayStage = 2
    else if m.overlayStage = 2
        if m.video.state <> "playing" or not m.banner.visible then return
        print "[setup-phone-normal] "; FormatJson({kind: "live-player-info", visible: m.banner.visible, playing: m.video.state = "playing"})
        openChannelBrowser()
        m.overlayStage = 3
    else if m.overlayStage = 3
        if m.video.state <> "playing" or not m.browser.active then return
        print "[setup-phone-normal] "; FormatJson({kind: "live-channel-browser", active: m.browser.active, focused: m.browser.hasFocus() or m.browser.isInFocusChain(), playing: m.video.state = "playing"})
        m.browser.active = false
        minimizePlayback()
        m.overlayStage = 4
    else if m.overlayStage = 4
        if m.video.state <> "playing" or not m.guide.active or not m.guide.miniActive then return
        print "[setup-phone-normal] "; FormatJson({kind: "live-guide-mini", active: m.guide.active, mini: m.guide.miniActive, playing: m.video.state = "playing"})
        stopPlayback()
        if m.capabilities.movies = "allowed" then openVodLibrary("movie")
        m.overlayStage = 5
    else if m.overlayStage = 5
        if m.page = "library"
            library = m.vod.callFunc("libraryStatus")
            if library.loading then return
            print "[setup-phone-normal] "; FormatJson({kind: "live-vod-controls", active: m.vod.active, loaded: library.loaded, failed: library.failure <> ""})
            closeVodLibrary()
        else
            print "[setup-phone-normal] "; FormatJson({kind: "live-vod-controls", active: false})
        end if
        if m.capabilities.dvr = "view" or m.capabilities.dvr = "manage" then openDvrLibrary()
        m.overlayStage = 6
    else if m.overlayStage = 6
        if m.page = "dvr"
            status = m.dvr.findNode("status").text
            if status = "" or instr(1, status, "Refreshing") = 1 then return
            print "[setup-phone-normal] "; FormatJson({kind: "live-dvr-controls", active: m.dvr.active, listed: left(status, 14) = "Recording now:"})
            closeDvrLibrary()
        else
            print "[setup-phone-normal] "; FormatJson({kind: "live-dvr-controls", active: false})
        end if
        finishPhoneNormalProbe(true, "complete")
    end if
end sub
'''
            if name == "components/GuideView.xml":
                data = data.replace(b"<interface>", b'<interface>\\n    <function name="probeLiveProgramDetails" />\\n    <function name="probeLiveGuideGroups" />', 1)
            if name == "components/GuideView.brs":
                data += b'''
function probeLiveProgramDetails() as object
    pending = {sampled: false, hasArt: false, status: ""}
    if not m.details.active
        cell = selectedCell()
        if cell = invalid then return pending
        if cell.program = invalid then return pending
        if PROBE_STALE_AIRING
            if cell.program.id = "" then return pending
            cancelProgramDetail()
            m.detailProgram = {}
            m.detailProgram.append(cell.program)
            m.detailProgram.id = "9000000000000000000"
            m.detailProgram.poster = ""
            m.detailProgram.artSource = ""
            m.detailChannel = m.filtered[m.selected]
            updateRichDetails()
            m.details.active = true
            loadProgramDetail()
        else
            showDetails()
        end if
        return pending
    end if
    if m.detailTask <> invalid then return pending
    hasArt = programArtworkUri(m.base, m.detailProgram.poster) <> ""
    status = m.details.callFunc("probePosterStatus")
    if hasArt and status <> "ready" and status <> "failed" then return pending
    m.details.active = false
    m.top.setFocus(true)
    return {sampled: true, hasArt: hasArt, status: status, recovered: PROBE_STALE_AIRING and m.detailCache.doesExist("9000000000000000000")}
end function

function probeLiveGuideGroups() as object
    current = m.groupIndex
    empty = false
    for i = 0 to m.groups.count() - 1
        if m.groups[i].id = "favorites"
            m.groupIndex = i
            filterLineup()
            drawGuide()
            empty = m.filtered.count() = 0 and not m.subtitle.visible
            exit for
        end if
    end for
    m.groupIndex = current
    filterLineup()
    drawGuide()
    return {kind: "live-guide-groups", empty_clean: empty, restored: m.filtered.count() > 0, light: uiAppearance().appearanceMode = "light"}
end function
'''.replace(b"PROBE_STALE_AIRING", b"true" if stale_airing else b"false")
            if name == "components/ProgramDetails.xml":
                data = data.replace(b"<interface>", b'<interface>\\n    <function name="probePosterStatus" />', 1)
            if name == "components/ProgramDetails.brs":
                data += b'\nfunction probePosterStatus() as string\n    return m.poster.loadStatus\nend function\n'
            target.writestr(name, data)
    intermediate.unlink()


if __name__ == "__main__":
    runner.build = build
    report = runner.main()
    events = {row["kind"]: row for row in report["events"]}
    if stale_airing:
        details = events.get("live-program-details", {})
        if details.get("recovered") is not True or details.get("poster_status") != "ready":
            raise SystemExit("Stale airing did not recover artwork from live Dispatcharr")
    for kind, required in {
        "live-player-info": ("visible", "playing"),
        "live-guide-groups": ("restored", "light", "empty_clean"),
        "live-channel-browser": ("active", "focused", "playing"),
        "live-guide-mini": ("active", "mini", "playing"),
    }.items():
        if not all(events.get(kind, {}).get(field) is True for field in required):
            raise SystemExit(f"Missing or failed overlay observation: {kind}")
    print("Live overlay assertions passed")
