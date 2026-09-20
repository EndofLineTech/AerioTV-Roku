sub init()
    m.top.backgroundColor = "0x0A1628FF"
    m.memory = CreateObject("roAppMemoryMonitor")
    m.release = m.top.findNode("release")
    m.release.observeField("fire", "releaseSample")
    m.task = CreateObject("roSGNode", "CacheProbeTask")
    m.task.observeField("sample", "onSample")
    m.task.observeField("report", "onReport")
    m.task.control = "RUN"
end sub

sub onSample()
    sample = m.task.sample
    if sample = invalid then return
    if sample.count() = 0 then return
    m.sample = sample
    print "[cache-probe-copy] "; FormatJson({rows: sample.count(), percent: m.memory.getMemoryLimitPercent(), availableKB: m.memory.getChannelAvailableMemory()})
    m.task.sample = []
    m.release.control = "start"
end sub

sub releaseSample()
    m.sample = invalid
end sub

sub onReport()
    print "[cache-probe-report] "; FormatJson(m.task.report)
    m.top.done = true
end sub
