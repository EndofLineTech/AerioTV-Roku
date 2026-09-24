sub runLegacyRosterProbe()
    m.legacyProbeTask = CreateObject("roSGNode", "LegacyRosterProbeTask")
    m.legacyProbeTask.observeField("result", "onLegacyRosterProbe")
    m.legacyProbeTask.control = "RUN"
end sub

sub onLegacyRosterProbe(event as object)
    if m.legacyProbeTask = invalid then return
    if not m.legacyProbeTask.isSameNode(event.getRoSGNode()) then return
    ok = event.getData().ok = true
    m.legacyProbeTask.unobserveField("result")
    m.legacyProbeTask = invalid
    if ok then print "[legacy-roster-probe] migration-and-recovery=PASS" else print "[legacy-roster-probe] migration-and-recovery=FAIL"
end sub
