sub init()
    m.top.functionName = "clearCache"
end sub
sub clearCache()
    metadataCacheClear(m.top.scope)
    m.top.done = true
end sub
