' This fixture runs only in out/xmltv-probe.zip, never the normal channel.
sub runXmltvProbe()
    m.xmltvProbeTask = CreateObject("roSGNode", "XmltvProbeTask")
    m.xmltvProbeTask.observeField("result", "onXmltvProbeResult")
    m.xmltvProbeTask.control = "RUN"
end sub

sub onXmltvProbeResult(event as object)
    if m.xmltvProbeTask = invalid then return
    if not m.xmltvProbeTask.isSameNode(event.getRoSGNode()) then return
    ok = event.getData().ok = true
    large = event.getData().large = true
    m.xmltvProbeTask.unobserveField("result")
    m.xmltvProbeTask = invalid
    if ok
        if large
            print "[xmltv-probe] large-feed=PASS channels="; event.getData().channels; " programs="; event.getData().count; " scan-seconds="; event.getData().elapsed
        else
            print "[xmltv-probe] file-window=PASS native-fragment=PASS"
        end if
    else
        print "[xmltv-probe] file-window=FAIL reason="; event.getData().reason
    end if
end sub
