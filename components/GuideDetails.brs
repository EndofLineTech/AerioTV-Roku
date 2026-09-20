sub cancelProgramDetail()
    m.detailDelay.control = "stop"
    if m.detailTask <> invalid
        m.detailTask.unobserveField("result")
        cancelNetworkTask(m.detailTask)
        m.detailTask = invalid
    end if
end sub

sub loadProgramDetail()
    if not m.ready or not m.top.active then return
    cell = selectedCell()
    if cell = invalid then return
    if cell.program = invalid then return
    candidates = [cell.program.id]
    if m.details.active
        candidates = [m.detailProgram.id]
    else if not m.searchView.active
        ' Selected program plus at most two visible airings per row. The working
        ' set stays below the 32-item cache so prefetch cannot churn forever.
        for i = m.rowStart to m.filtered.count() - 1
            if i >= m.rowStart + m.rowCount then exit for
            count = 0
            for each visibleCell in rowCells(m.filtered[i])
                if visibleCell.program <> invalid
                    candidates.push(visibleCell.program.id)
                    count++
                    if count >= 2 then exit for
                end if
            end for
        end for
    end if
    id = ""
    for each candidate in candidates
        available = CreateObject("roRegex", "^[0-9]+$", "").isMatch(candidate)
        if m.detailCache.doesExist(candidate)
            if m.detailCache[candidate].fetchedAt > uiNow() - 300 then available = false
        end if
        if m.detailFailures.doesExist(candidate)
            if m.detailFailures[candidate] > uiNow() then available = false
        end if
        if available
            id = candidate
            exit for
        end if
    end for
    if id = "" then return
    if m.detailTask <> invalid
        if m.detailTask.programId = id then return
        cancelProgramDetail()
    end if
    m.detailTask = CreateObject("roSGNode", "ProgramDetailTask")
    m.detailTask.baseUrl = m.base
    m.detailTask.apiKey = m.key
    m.detailTask.programId = id
    if m.settings.tmdbFallback then m.detailTask.tmdbKey = m.tmdbKey
    m.detailTask.observeField("result", "onProgramDetail")
    m.detailTask.control = "RUN"
end sub

sub onProgramDetail(event as object)
    if not isCurrentTaskEvent(event, m.detailTask) then return
    result = event.getData()
    m.detailTask.unobserveField("result")
    m.detailTask = invalid
    if result.ok
        result.program.fetchedAt = uiNow()
        m.detailCache[result.id] = result.program
        order = []
        for each id in m.detailOrder
            if id <> result.id then order.push(id)
        end for
        m.detailOrder = order
        m.detailOrder.push(result.id)
        if m.detailOrder.count() > 32 then m.detailCache.delete(m.detailOrder.shift())
        if m.details.active and m.detailProgram.id = result.id
            m.detailProgram = mergeProgramFacts(m.detailProgram, result.program)
            updateRichDetails()
        end if
        if m.top.active then drawGuide()
    else
        if m.detailFailures.count() >= 64 then m.detailFailures = {}
        m.detailFailures[result.id] = uiNow() + 60
    end if
end sub

sub updateRichDetails()
    m.details.model = {program: m.detailProgram, channel: m.detailChannel, baseUrl: m.base, apiKey: m.key, settings: m.settings, reminded: hasReminder(m.reminders, m.detailChannel.uuid, m.detailProgram.id)}
end sub

sub updateReminders()
    if not m.ready then return
    m.reminders = normalizeReminders(m.top.reminderState)
    if m.details.active then updateRichDetails()
    if m.top.active then drawGuide()
end sub

sub onRichDetailAction(event as object)
    action = event.getData()
    if action = "reminder"
        id = m.detailChannel.uuid + "|" + m.detailProgram.id
        found = false
        kept = []
        for each entry in m.reminders
            if entry.id = id then found = true else kept.push(entry)
        end for
        if not found and kept.count() >= 50
            model = m.details.model
            model.message = "Reminder limit reached (50). Cancel an existing reminder from Guide options."
            m.details.model = model
            return
        end if
        if not found and kept.count() < 50
            p = m.detailProgram
            kept.push({id: id, channelUuid: m.detailChannel.uuid, title: p.title, startsAt: p.startsAt, endsAt: p.endsAt, notified: false})
        end if
        m.reminders = kept
        savePreferences()
        updateRichDetails()
        return
    end if
    m.details.active = false
    m.top.setFocus(true)
    if action = "watch" then m.top.watchChannel = m.detailChannel
end sub
