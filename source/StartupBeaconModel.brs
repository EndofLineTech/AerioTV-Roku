' Shared startup accounting. Complete the dialog when a user gate closes;
' signal launch only after the authorized home/guide has fully rendered.
sub beginStartupBeacons(welcome as boolean)
    m.startupBeaconSent = false
    m.startupDialogOpen = false
    if not welcome then beginStartupDialog()
end sub

sub beginStartupDialog()
    if m.startupDialogOpen or m.startupBeaconSent then return
    m.startupDialogOpen = true
    m.top.signalBeacon("AppDialogInitiate")
end sub

sub completeStartupDialog()
    if not m.startupDialogOpen then return
    m.top.signalBeacon("AppDialogComplete")
    m.startupDialogOpen = false
end sub

sub completeStartupBeacons()
    if m.startupBeaconSent then return
    completeStartupDialog()
    m.top.signalBeacon("AppLaunchComplete")
    m.startupBeaconSent = true
end sub
