"""Private live Dispatcharr overlay probe; isolated registry and exact restore."""
import importlib.util
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("normal", root / "scripts/test-phone-setup-normal-native.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
original = runner.build


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
    if m.overlayClock.totalMilliseconds() > 45000
        finishPhoneNormalProbe(false, "overlay-timeout-" + m.overlayStage.toStr())
        return
    end if
    if m.overlayStage = 0
        facts = m.guide.callFunc("probeLiveProgramDetails")
        if not facts.sampled and m.overlayClock.totalMilliseconds() < 12000 then return
        print "[setup-phone-normal] "; FormatJson({kind: "live-program-details", sampled: facts.sampled, has_art: facts.hasArt, poster_status: facts.status})
        model = m.guide.callFunc("playerBrowserData")
        if model.channels.count() = 0 then finishPhoneNormalProbe(false, "no-live-channel") : return
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
        finishPhoneNormalProbe(true, "complete")
    end if
end sub
'''
            if name == "components/GuideView.xml":
                data = data.replace(b"<interface>", b'<interface>\\n    <function name="probeLiveProgramDetails" />', 1)
            if name == "components/GuideView.brs":
                data += b'''
function probeLiveProgramDetails() as object
    pending = {sampled: false, hasArt: false, status: ""}
    if not m.details.active
        cell = selectedCell()
        if cell = invalid then return pending
        if cell.program = invalid then return pending
        showDetails()
        return pending
    end if
    if m.detailTask <> invalid then return pending
    hasArt = programArtworkUri(m.base, m.detailProgram.poster) <> ""
    status = m.details.callFunc("probePosterStatus")
    if hasArt and status <> "ready" and status <> "failed" then return pending
    m.details.active = false
    m.top.setFocus(true)
    return {sampled: true, hasArt: hasArt, status: status}
end function
'''
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
    for kind, required in {
        "live-player-info": ("visible", "playing"),
        "live-channel-browser": ("active", "focused", "playing"),
        "live-guide-mini": ("active", "mini", "playing"),
    }.items():
        if not all(events.get(kind, {}).get(field) is True for field in required):
            raise SystemExit(f"Missing or failed overlay observation: {kind}")
    print("Live overlay assertions passed")
