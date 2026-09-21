sub main()
    defaults = defaultRemoteMap()
    assertEqual(defaults.version, 1, "remote map version")
    assertEqual(defaults.preset, "default", "default preset")
    assertEqual(resolveRemoteAction(defaults, "player", "okShort"), "toggleInfo", "player default")
    assertEqual(resolveRemoteAction(defaults, "guide", "replay"), "jumpToNow", "guide default")
    assertEqual(resolveRemoteAction(defaults, "player", "back"), "", "Back is never a slot")
    assertEqual(resolveRemoteAction(defaults, "player", "options"), "", "Options is never a slot")

    custom = normalizeRemoteMap({version: 1, preset: "custom", player: {rightShort: "recentChannels", back: "stopPlayback"}, guide: {replay: "openOptions", upShort: "jumpToNow"}})
    assertEqual(custom.preset, "custom", "custom preset survives")
    assertEqual(resolveRemoteAction(custom, "player", "rightShort"), "recentChannels", "custom player override")
    assertEqual(resolveRemoteAction(custom, "player", "leftShort"), "channelList", "sparse player fallback")
    assertEqual(resolveRemoteAction(custom, "guide", "replay"), "openOptions", "custom guide override")
    assertEqual(resolveRemoteAction(custom, "guide", "upShort"), "", "fixed guide navigation cannot be remapped")
    assertEqual(resolveRemoteAction(custom, "player", "back"), "", "Back override discarded")

    disabled = setRemoteAction(custom, "player", "replay", "none")
    assertEqual(disabled.preset, "custom", "edit keeps custom preset")
    assertEqual(resolveRemoteAction(disabled, "player", "replay"), "none", "explicit none survives")
    assertEqual(setRemoteAction(custom, "player", "options", "recentChannels").preset, "custom", "unsupported slot ignored")
    assertEqual(resolveRemoteAction(setRemoteAction(custom, "guide", "replay", "recentChannels"), "guide", "replay"), "openOptions", "unsupported action ignored")

    tracked = normalizeRemoteMap({version: 1, preset: "default", player: {replay: "none"}, guide: {replay: "openOptions"}})
    assertEqual(resolveRemoteAction(tracked, "player", "replay"), "recentChannels", "default preset ignores saved slots")
    assertEqual(resolveRemoteAction(tracked, "guide", "replay"), "jumpToNow", "default guide slots ignored")
    assertEqual(normalizeRemoteMap({version: 2, preset: "custom", player: {replay: "none"}}).preset, "default", "unknown map version falls back")
    assertEqual(normalizeRemoteMap({version: 1, preset: "unknown"}).preset, "default", "unknown preset falls back")
    assertEqual(resetRemoteMap().preset, "default", "reset restores default preset")

    playerActions = remoteActionChoices("player", "rightShort")
    if playerActions.count() < 3 or playerActions[0] <> "channelUp" then stop
    guideActions = remoteActionChoices("guide", "replay")
    if guideActions.count() <> 3 or guideActions[1] <> "openOptions" then stop
    if remoteActionChoices("guide", "upShort").count() <> 0 then stop
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
