' Device-only fixture: no network or real account registry access. Launch twice.
sub init()
    m.label = m.top.findNode("status")
    registry = CreateObject("roRegistrySection", "AerioTVVodRetentionProbeV1")
    memory = CreateObject("roAppMemoryMonitor")
    if registry.read("settingsV1") <> ""
        store = loadPreferenceStore(registry)
        entries = vodState(store.accounts[preferenceScope("fixture|A")].vod)
        other = vodState(store.accounts[preferenceScope("fixture|B")].vod)
        ok = entries.count() = 60 and other.count() = 1
        if ok
            for i = 1 to 40
                kind = "movie"
                if i mod 2 = 0 then kind = "episode"
                item = vodNormalize({id: i, uuid: "pin-" + i.toStr(), name: "Pinned"}, kind)
                if not vodStateEntry(entries, item).watchlist then ok = false
            end for
            extra = vodNormalize({id: 100, uuid: "extra", name: "Extra"}, "movie")
            if vodStateUpdate(entries, extra, {watchlist: true}) <> invalid then ok = false
            if vodStateEntry(other, item).watchlist then ok = false
        end if
        cleared = registry.delete("settingsV1")
        cleared = registry.flush() and cleared
        print "[vod-retention-probe] reload ok="; ok; " rows="; entries.count(); " other="; other.count(); " cleanup="; cleared; " memory-percent="; memory.getMemoryLimitPercent()
        result = "FAIL"
        if ok and cleared then result = "PASS"
        m.label.text = "VOD retention reload " + result + "; isolated registry cleanup checked"
        return
    end if

    store = defaultPreferenceStore()
    entries = []
    for i = 1 to 40
        kind = "movie"
        if i mod 2 = 0 then kind = "episode"
        item = vodNormalize({id: i, uuid: "pin-" + i.toStr(), name: "Pinned"}, kind)
        item.authorization = "A"
        entries = vodStateUpdate(entries, item, {watchlist: true})
    end for
    for i = 1 to 30
        item = vodNormalize({id: 200 + i, uuid: "recent-" + i.toStr(), name: "Recent"}, "episode")
        entries = vodStateUpdate(entries, item, {position: 100, duration: 1000})
    end for
    other = vodNormalize({id: 300, uuid: "other", name: "Other"}, "movie")
    other.authorization = "B"
    store.accounts[preferenceScope("fixture|A")] = {vod: entries}
    store.accounts[preferenceScope("fixture|B")] = {vod: vodStateUpdate([], other, {hidden: true})}
    bytes = preferenceByteBudget(FormatJson(store))
    ok = entries.count() = 60 and savePreferenceStore(registry, store)
    print "[vod-retention-probe] seed ok="; ok; " bytes="; bytes; " rows="; entries.count(); " memory-percent="; memory.getMemoryLimitPercent()
    result = "FAIL"
    if ok then result = "PASS"
    m.label.text = "VOD retention seed " + result + "; " + bytes.toStr() + " bytes. Relaunch once to verify and clean up."
end sub
