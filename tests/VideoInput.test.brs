sub main()
    m.top = {optionsKeyPress: false}
    init()
    if m.top.allowOptionsKeyOverride or m.top.enableUI then stop
    if onKeyEvent("options", true) then stop
    m.top.allowOptionsKeyOverride = true ' mini-guide forwarding only
    if not onKeyEvent("options", true) then stop
    if not m.top.optionsKeyPress then stop
    if not onKeyEvent("options", false) then stop
    if m.top.optionsKeyPress then stop
    if not onKeyEvent("OK", true) then stop
    if m.top.playerKey.key <> "OK" or not m.top.playerKey.press then stop
    if not onKeyEvent("OK", false) then stop
    if m.top.playerKey.press then stop
    print "ALL TESTS PASSED"
end sub
