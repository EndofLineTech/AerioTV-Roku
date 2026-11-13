sub main()
    resetBeacons()
    beginStartupBeacons(false)
    beginStartupDialog()
    check(m.beacons.count() = 1 and m.beacons[0] = "AppDialogInitiate", "startup dialog initiates once")
    completeStartupDialog()
    check(m.beacons.count() = 2 and not m.startupDialogOpen and not m.startupBeaconSent, "dialog closes before slow guide work, not launch completion")
    completeStartupDialog()
    completeStartupBeacons()
    completeStartupBeacons()
    check(m.beacons.count() = 3 and m.beacons[2] = "AppLaunchComplete", "fully rendered guide signals launch once")
    resetBeacons()
    beginStartupBeacons(true)
    completeStartupBeacons()
    check(m.beacons.count() = 1 and m.beacons[0] = "AppLaunchComplete", "welcome can complete without an auth dialog")
    print "ALL TESTS PASSED"
end sub

sub resetBeacons()
    m.beacons = []
    m.top = {beacons: m.beacons, signalBeacon: sub(value as string)
        m.beacons.push(value)
    end sub}
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
