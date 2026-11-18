"""Disposable, live-account native guide sweep. No owner registry or provider writes."""
import importlib.util
import sys
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("phone_normal", root / "scripts/test-phone-setup-normal-native.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
original_build = runner.build
seed_logo_failure = False
limit_poster_size = False
page_scroll = False

def build(output, *args, **kwargs):
    intermediate = output.with_suffix(".base.zip")
    original_build(intermediate, *args, **kwargs)
    with zipfile.ZipFile(intermediate) as original, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as updated:
        for name in original.namelist():
            data = original.read(name)
            if name == "components/AerioScene.brs":
                anchor = '        finishPhoneNormalProbe(passed, "complete")'
                text = data.decode()
                assert text.count(anchor) == 1
                data = text.replace(anchor, '''        if not passed then finishPhoneNormalProbe(false, "profile-switch") : return
        if m.guide.callFunc("liveGuideSweep") then finishPhoneNormalProbe(true, "complete")''').encode()
            if name == "components/GuideView.xml":
                data = data.replace(b'<interface>', b'<interface>\n    <function name="liveGuideSweep" />', 1)
            if name == "components/GuideView.brs":
                if limit_poster_size:
                    anchor = b'        logo.loadDisplayMode = "scaleToFit"\n'
                    assert data.count(anchor) == 1
                    data = data.replace(anchor, b'        logo.loadDisplayMode = "limitSize"\n')
                data += b'''

function liveSweepMenuEvent(node as object, index as integer) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.index
    end function}
end function

sub liveSweepMeasurePosters(elapsed as integer)
    if m.mappingState <> "ready" or m.liveSweepTimingDone = true then return
    expected = 0
    cached = 0
    ready = 0
    maxBytes = 0
    maxBitmapPixels = 0
    for each row in m.rows
        if row.root.visible and channelLogoCacheKeyValid(row.logoId)
            expected++
            if m.guideLogoFiles.doesExist(row.logoId)
                asset = m.guideLogoFiles[row.logoId]
                cached++
                if asset.bytes > maxBytes then maxBytes = asset.bytes
                if row.logo.uri = asset.uri and row.logo.loadStatus = "ready"
                    ready++
                    pixels = int(row.logo.bitmapWidth * row.logo.bitmapHeight)
                    if pixels > maxBitmapPixels then maxBitmapPixels = pixels
                end if
            end if
        end if
    end for
    if expected = 0 then return
    age = elapsed - m.liveSweepViewportAt
    if cached = expected and m.liveSweepAllCachedAt = invalid then m.liveSweepAllCachedAt = age
    if ready = expected or age >= 15000
        m.liveSweepTimingDone = true
        print "[setup-phone-normal] "; FormatJson({kind: "live-guide-poster-timing", row_start: m.rowStart, eligible: expected, ready: ready, all_cached_ms: m.liveSweepAllCachedAt, sample_ms: age, settled: ready = expected, max_cached_logo_bytes: maxBytes, max_bitmap_pixels: maxBitmapPixels})
    end if
end sub

function liveGuideSweep() as boolean
    if not m.top.active or not m.ready then return false
    if m.liveSweepClock = invalid
        m.liveSweepClock = CreateObject("roTimespan")
        m.liveSweepClock.mark()
        m.liveSweepSamples = 0
        m.liveSweepCoverage = {}
        m.liveSweepViewportAt = 0
        return false
    end if
    elapsed = m.liveSweepClock.totalMilliseconds()
    if elapsed >= 280000 then return true
    liveSweepMeasurePosters(elapsed)
    if m.liveSweepNextSampleAt = invalid then m.liveSweepNextSampleAt = 20000
    if elapsed < m.liveSweepNextSampleAt then return false
    if LIVE_SWEEP_FAULT and m.liveSweepSamples = 1 and m.liveSweepRetryId <> invalid
        if m.liveSweepRefreshAt = invalid
            print "[setup-phone-normal] "; FormatJson({kind: "live-guide-seeded-failure", suppressed: m.guideLogoFailed.doesExist(m.liveSweepRetryId)})
            openPicker("Guide sweep", [{title: "Refresh guide", action: "refresh"}], "options")
            onPickerSelected(liveSweepMenuEvent(m.pickerList, 0))
            m.liveSweepRefreshAt = elapsed
            return false
        end if
        downloaded = m.guideLogoFiles.doesExist(m.liveSweepRetryId)
        suppressed = m.guideLogoFailed.doesExist(m.liveSweepRetryId)
        if not downloaded and not suppressed and elapsed - m.liveSweepRefreshAt < 25000 then return false
        if m.liveSweepRetryReported <> true
            print "[setup-phone-normal] "; FormatJson({kind: "live-guide-refresh-retry", downloaded: downloaded, still_suppressed: suppressed})
            m.liveSweepRetryReported = true
        end if
        if m.mappingState = "loading" then return false
    end if
    visibleCount = 0
    hasId = 0
    cached = 0
    ready = 0
    failed = 0
    loading = 0
    otherStatus = 0
    wrongUri = 0
    mapped = 0
    populated = 0
    for each channel in m.channels
        if channel.epgKey <> "" then mapped++
    end for
    for each row in m.rows
        if row.root.visible
            idx = m.rowStart + visibleCount
            visibleCount++
            m.liveSweepCoverage[idx.toStr()] = true
            if channelLogoCacheKeyValid(row.logoId)
                hasId++
                if m.guideLogoFiles.doesExist(row.logoId)
                    cached++
                    if row.logo.uri <> m.guideLogoFiles[row.logoId].uri
                        wrongUri++
                    else if row.logo.loadStatus = "ready"
                        ready++
                    else if row.logo.loadStatus = "failed"
                        failed++
                    else if row.logo.loadStatus = "loading"
                        loading++
                    else
                        otherStatus++
                    end if
                end if
            end if
            if idx < m.filtered.count()
                cells = rowCells(m.filtered[idx])
                for each cell in cells
                    if cell.program <> invalid then populated++ : exit for
                end for
            end if
        end if
    end for
    print "[setup-phone-normal] "; FormatJson({kind: "live-guide-sweep", lineup: m.channels.count(), filtered: m.filtered.count(), row_start: m.rowStart, selected: m.selected, visible: visibleCount, eligible_logos: hasId, cached: cached, ready: ready, failed_decode: failed, loading: loading, other_poster_status: otherStatus, wrong_uri_count: wrongUri, mapping_ready: m.mappingState = "ready", mapping_warning: m.mappingWarning <> "", epg_keys: mapped, program_rows: populated, covered_rows: m.liveSweepCoverage.count(), active_logo_task: m.guideLogoTask <> invalid})
    ' Hold the same viewport for one more bounded sample if its images are
    ' still loading. Moving on would hide whether they ever settled.
    if loading > 0 and m.liveSweepHeld <> true
        m.liveSweepHeld = true
        m.liveSweepNextSampleAt = elapsed + 10000
        return false
    end if
    m.liveSweepHeld = false
    m.liveSweepNextSampleAt = elapsed + 5000
    if LIVE_SWEEP_FAULT and m.liveSweepSamples = 0 and m.selected + 1 < m.filtered.count() and m.rowStart + visibleCount < m.filtered.count()
        retryId = channelLogoCacheId(m.filtered[m.rowStart + visibleCount])
        if channelLogoCacheKeyValid(retryId) and not m.guideLogoFiles.doesExist(retryId)
            m.liveSweepRetryId = retryId
            m.guideLogoFailed[retryId] = true
        end if
    end if
    m.liveSweepSamples++
    ' Bound the run, but allow enough six-row viewports to cover a 91-row guide.
    if m.selected >= m.filtered.count() - 1 or m.liveSweepSamples >= 20 then return true
    if LIVE_SWEEP_PAGE
        executeGuideRemoteAction("pageDown")
        finishGuideMappedAction()
    else
        for stepIndex = 1 to visibleCount
            if m.selected >= m.filtered.count() - 1 then exit for
            consumed = onKeyEvent("down", true)
            consumed = onKeyEvent("down", false)
        end for
    end if
    m.liveSweepViewportAt = m.liveSweepClock.totalMilliseconds()
    m.liveSweepAllCachedAt = invalid
    m.liveSweepTimingDone = false
    return false
end function
'''.replace(b"LIVE_SWEEP_FAULT", b"true" if seed_logo_failure else b"false").replace(
                    b"LIVE_SWEEP_PAGE", b"true" if page_scroll else b"false")
            if name == "components/GuideCache.brs":
                data = data.replace(b'    result = event.getData()\n    m.top.metadataEvent = {ok: result.ok, stage: "mapping"', b'''    result = event.getData()
    count = 0
    if type(result.links) = "roAssociativeArray" then count = result.links.count()
    print "[setup-phone-normal] "; FormatJson({kind: "live-guide-mapping", ok: result.ok, source: result.source, links: count, elapsed_ms: m.metadataElapsed.totalMilliseconds()})
    m.top.metadataEvent = {ok: result.ok, stage: "mapping"''', 1)
            updated.writestr(name, data)

def assert_guide_sweep(events, expect_retry=False):
    samples = [row for row in events if row["kind"] == "live-guide-sweep"]
    if not samples or samples[-1]["lineup"] <= 0 or samples[-1]["covered_rows"] != samples[-1]["lineup"] or not all(
        row["mapping_ready"] and not row["mapping_warning"] and row["visible"] > 0 for row in samples
    ):
        raise SystemExit("Guide sweep did not cover the full lineup with mappings ready")
    if expect_retry:
        seeded = [row for row in events if row["kind"] == "live-guide-seeded-failure"]
        retries = [row for row in events if row["kind"] == "live-guide-refresh-retry"]
        if (len(seeded) != 1 or not seeded[0]["suppressed"] or len(retries) != 1
                or not retries[0]["downloaded"] or retries[0]["still_suppressed"]):
            raise SystemExit("Refresh did not recover the seeded logo failure")


if __name__ == "__main__":
    seed_logo_failure = "--seed-logo-failure" in sys.argv
    limit_poster_size = "--limit-poster-size" in sys.argv
    page_scroll = "--page-scroll" in sys.argv
    if seed_logo_failure:
        sys.argv.remove("--seed-logo-failure")
    if limit_poster_size:
        sys.argv.remove("--limit-poster-size")
    if page_scroll:
        sys.argv.remove("--page-scroll")
    runner.build = build
    report = runner.main()
    assert_guide_sweep(report["events"], expect_retry=seed_logo_failure)
    print("Guide sweep assertions passed", flush=True)
