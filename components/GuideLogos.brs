' The guide reuses six Poster nodes for hundreds of channels. Keep a bounded
' per-connection tmp:/ logo cache so revisiting a row does not refetch its URI.
sub initGuideLogos()
    m.guideLogoFiles = {}
    m.guideLogoOrder = []
    m.guideLogoBytes = 0
    m.guideLogoFailed = {}
    m.guideLogoTask = invalid
    m.guideLogoCleanup = invalid
    m.guideLogoCleanupPaths = []
    m.guideLogoPrefix = ""
    m.guideLogoSequence = 0
    m.guideLogoClock = invalid
    m.guideLogoFirstReported = false
    m.guideLogoBatchReported = false
    m.guideLogoFirstRendered = false
    m.guideLogoAllRendered = false
    m.guideLogoDelay = m.top.createChild("Timer")
    m.guideLogoDelay.duration = 0.15
    m.guideLogoDelay.observeField("fire", "requestGuideLogos")
end sub

sub resetGuideLogos()
    m.guideLogoDelay.control = "stop"
    if m.guideLogoTask <> invalid
        m.guideLogoTask.unobserveField("asset")
        m.guideLogoTask.unobserveField("result")
        m.guideLogoTask.cancelled = true
        for each id in m.guideLogoTask.ids
            for each ext in [".part", ".jpg", ".png", ".webp"]
                m.guideLogoCleanupPaths.push(m.guideLogoTask.prefix + "-" + id + ext)
            end for
        end for
        m.guideLogoTask = invalid
    end if
    for each id in m.guideLogoFiles
        m.guideLogoCleanupPaths.push(m.guideLogoFiles[id].uri)
    end for
    m.guideLogoFiles = {}
    m.guideLogoOrder = []
    m.guideLogoBytes = 0
    m.guideLogoFailed = {}
    m.guideLogoPrefix = "tmp:/aerio-guide-" + CreateObject("roDeviceInfo").getRandomUUID()
    m.guideLogoClock = invalid
    m.guideLogoFirstReported = false
    m.guideLogoBatchReported = false
    m.guideLogoFirstRendered = false
    m.guideLogoAllRendered = false
    cleanupGuideLogoFiles()
end sub

sub cleanupGuideLogoFiles()
    if m.guideLogoCleanup <> invalid or m.guideLogoCleanupPaths.count() = 0 then return
    m.guideLogoCleanup = CreateObject("roSGNode", "LogoCleanupTask")
    m.guideLogoCleanup.paths = m.guideLogoCleanupPaths
    m.guideLogoCleanupPaths = []
    m.guideLogoCleanup.observeField("done", "onGuideLogoCleanup")
    m.guideLogoCleanup.control = "RUN"
end sub

sub onGuideLogoCleanup(event as object)
    if not isCurrentTaskEvent(event, m.guideLogoCleanup) then return
    m.guideLogoCleanup.unobserveField("done")
    m.guideLogoCleanup = invalid
    cleanupGuideLogoFiles()
end sub

sub scheduleGuideLogos()
    if not m.top.active or m.key = "" or m.providerType <> "dispatcharr" then return
    m.guideLogoDelay.control = "stop"
    m.guideLogoDelay.control = "start"
end sub

' Begin the first visible batch as soon as the authorized lineup has been
' normalized. Its Task runs while the Scene builds the grid and resolves EPG
' mappings; later scrolling still uses the coalescing timer above.
sub prefetchInitialGuideLogos()
    if m.providerType <> "dispatcharr" or m.key = "" or not m.settings.showLogos then return
    rows = guidePresentationGeometry(m.settings.guideDensity, m.settings.showSubtitles).rowCount
    ids = guideInitialLogoIds(m.filtered, m.selected, rows)
    if ids.count() = 0 then return
    m.guideLogoClock = CreateObject("roTimespan")
    m.guideLogoClock.mark()
    print "[guide-logos] initial-prefetch="; ids.count()
    startGuideLogoBatch(ids)
end sub

sub startGuideLogoBatch(ids as object)
    if ids.count() = 0 or m.guideLogoTask <> invalid then return
    m.guideLogoTask = CreateObject("roSGNode", "LogoCacheTask")
    m.guideLogoTask.baseUrl = m.base
    m.guideLogoTask.apiKey = m.key
    m.guideLogoTask.ids = ids
    m.guideLogoSequence++
    m.guideLogoTask.prefix = m.guideLogoPrefix + "-" + m.guideLogoSequence.toStr()
    m.guideLogoTask.observeField("asset", "onGuideLogoAsset")
    m.guideLogoTask.observeField("result", "onGuideLogoBatch")
    m.guideLogoTask.control = "RUN"
end sub

sub requestGuideLogos()
    if not m.top.active or m.guideLogoTask <> invalid then return
    ids = []
    seen = {}
    numeric = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    for each row in m.rows
        id = textValue(row.logoId)
        if row.root.visible and numeric.isMatch(id) and not m.guideLogoFiles.doesExist(id) and not m.guideLogoFailed.doesExist(id) and not seen.doesExist(id)
            ids.push(id)
            seen[id] = true
        end if
    end for
    startGuideLogoBatch(ids)
end sub

sub touchGuideLogo(id as string)
    order = []
    for each old in m.guideLogoOrder
        if old <> id then order.push(old)
    end for
    order.push(id)
    m.guideLogoOrder = order
end sub

sub storeGuideLogo(asset as object)
    if m.guideLogoFiles.doesExist(asset.id) then return
    m.guideLogoFiles[asset.id] = asset
    m.guideLogoBytes += asset.bytes
    if m.guideLogoClock <> invalid and not m.guideLogoFirstReported
        print "[guide-logos] first-asset-ms="; m.guideLogoClock.totalMilliseconds()
        m.guideLogoFirstReported = true
    end if
    touchGuideLogo(asset.id)
    for each row in m.rows
        if row.root.visible and row.logoId = asset.id then row.logo.uri = asset.uri
    end for
    while m.guideLogoOrder.count() > 24 or m.guideLogoBytes > 12582912
        victim = ""
        for each id in m.guideLogoOrder
            visible = false
            for each row in m.rows
                if row.root.visible and row.logoId = id then visible = true
            end for
            if not visible
                victim = id
                exit for
            end if
        end for
        if victim = "" then exit while
        m.guideLogoBytes -= m.guideLogoFiles[victim].bytes
        m.guideLogoCleanupPaths.push(m.guideLogoFiles[victim].uri)
        m.guideLogoFiles.delete(victim)
        order = []
        for each id in m.guideLogoOrder
            if id <> victim then order.push(id)
        end for
        m.guideLogoOrder = order
    end while
    cleanupGuideLogoFiles()
end sub

' A successful download is not proof that the Poster has decoded its image.
' Report only aggregate first/all visible timings without channel IDs or URIs.
sub onGuideLogoStatus()
    if m.guideLogoClock = invalid or not m.ready or not m.top.active or not m.settings.showLogos then return
    expected = 0
    ready = 0
    numeric = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    for each row in m.rows
        id = textValue(row.logoId)
        if row.root.visible and numeric.isMatch(id)
            expected++
            if m.guideLogoFiles.doesExist(id) and row.logo.loadStatus = "ready" then ready++
        end if
    end for
    if ready > 0 and not m.guideLogoFirstRendered
        print "[guide-logos] first-poster-ready-ms="; m.guideLogoClock.totalMilliseconds()
        m.guideLogoFirstRendered = true
    end if
    if expected > 0 and ready = expected and not m.guideLogoAllRendered
        print "[guide-logos] visible-posters-ready="; ready; " elapsed_ms="; m.guideLogoClock.totalMilliseconds()
        m.guideLogoAllRendered = true
    end if
end sub

sub onGuideLogoAsset(event as object)
    if isCurrentTaskEvent(event, m.guideLogoTask) then storeGuideLogo(event.getData())
end sub

sub onGuideLogoBatch(event as object)
    if not isCurrentTaskEvent(event, m.guideLogoTask) then return
    result = event.getData()
    if m.guideLogoClock <> invalid and not m.guideLogoBatchReported
        print "[guide-logos] initial-batch-ready="; result.assets.count(); " failed="; result.failed.count(); " elapsed_ms="; m.guideLogoClock.totalMilliseconds()
        m.guideLogoBatchReported = true
    end if
    m.guideLogoTask.unobserveField("asset")
    m.guideLogoTask.unobserveField("result")
    m.guideLogoTask = invalid
    for each asset in result.assets
        storeGuideLogo(asset)
    end for
    for each id in result.failed
        m.guideLogoFailed[id] = true
    end for
    scheduleGuideLogos()
end sub
