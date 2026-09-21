sub cancelMappingLoad()
    if m.cacheClearTask <> invalid
        m.cacheClearTask.unobserveField("done")
        m.cacheClearTask = invalid
    end if
    if m.mappingTask <> invalid
        m.mappingTask.unobserveField("result")
        cancelNetworkTask(m.mappingTask)
        m.mappingTask = invalid
    end if
end sub

sub cancelMetadataLoads()
    cancelMappingLoad()
    if m.task <> invalid
        m.task.unobserveField("result")
        m.task.unobserveField("cached")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
end sub

function forgetStoredMetadata() as object
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    cancelMetadataLoads()
    task = CreateObject("roSGNode", "CacheClearTask")
    task.scope = m.cacheScope
    task.control = "RUN"
    return task
end function

sub loadMappings(bypass = false as boolean)
    cancelMappingLoad()
    m.mappingState = "loading"
    m.mappingWarning = ""
    m.mappingTask = CreateObject("roSGNode", "MappingTask")
    m.mappingTask.baseUrl = m.base
    m.mappingTask.apiKey = m.key
    m.mappingTask.channels = m.channels
    m.mappingTask.scope = m.cacheScope
    m.mappingTask.generation = m.lineupGeneration
    m.mappingTask.cacheEpoch = m.global.cacheEpoch
    m.mappingTask.bypassCache = bypass
    m.mappingTask.observeField("result", "onMappingsLoaded")
    m.mappingTask.control = "RUN"
end sub

sub onMappingsLoaded(event as object)
    if not isCurrentTaskEvent(event, m.mappingTask) then return
    result = event.getData()
    m.top.metadataEvent = {ok: result.ok, stage: "mapping", source: textValue(result.source), elapsedMs: m.metadataElapsed.totalMilliseconds(), message: textValue(result.message)}
    m.mappingTask.unobserveField("result")
    m.mappingTask = invalid
    m.mappingState = "ready"
    m.allowedKeys = guideDictionary()
    for each channel in m.channels
        channel.epgKey = guideMappingKey(channel, result)
        m.allowedKeys[channel.uuid] = true
        if channel.epgKey <> "" then m.allowedKeys[channel.epgKey] = true
    end for
    if result.ok
        m.cacheGeneration = metadataCacheDigest(m.lineupGeneration + "|" + FormatJson(result.links))
        print "[guide-mapping] source="; result.source; " links="; result.links.count(); " ms-after-lineup="; m.metadataElapsed.totalMilliseconds()
    else
        m.cacheGeneration = metadataCacheDigest(m.lineupGeneration + "|mapping-unavailable")
        m.mappingWarning = "Guide mappings unavailable. Live tuning works; * > Refresh guide retries."
    end if
    if m.top.active then drawGuide()
    publishPlaybackInfo()
    scheduleLoad()
end sub

function guideMappingKey(channel as object, result as object) as string
    key = textValue(channel.tvgId)
    if result.ok and channel.epgId <> "" and result.links.doesExist(channel.epgId) then key = textValue(result.links[channel.epgId])
    return key
end function

sub onWindowCached(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    cached = event.getData()
    guideCachePut(m.cache, cached.windowStart, cached.index, cached.fetched)
    m.message = "Showing cached guide while refreshing..."
    if m.top.active then drawGuide()
    publishPlaybackInfo()
end sub

sub clearStoredGuideCache()
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    if m.task <> invalid
        m.task.unobserveField("result")
        m.task.unobserveField("cached")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
    cancelMappingLoad()
    m.mappingState = "loading"
    m.cache = guideNewCache()
    m.failures = {}
    m.forceGuideFetch = true
    m.cacheClearTask = CreateObject("roSGNode", "CacheClearTask")
    m.cacheClearTask.scope = m.cacheScope
    m.cacheClearTask.observeField("done", "onStoredCacheCleared")
    m.cacheClearTask.control = "RUN"
    m.message = "Clearing cached guide data..."
end sub

sub onStoredCacheCleared(event as object)
    if not isCurrentTaskEvent(event, m.cacheClearTask) then return
    m.cacheClearTask.unobserveField("done")
    m.cacheClearTask = invalid
    loadMappings(true)
    if m.top.active then drawGuide()
end sub
