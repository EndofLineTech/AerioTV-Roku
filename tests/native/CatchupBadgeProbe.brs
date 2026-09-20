' Temporary GuideView-local fixture. Remove init/XML hooks after validation.
sub installCatchupBadgeProbe()
    m.badgeProbeTimer = m.top.createChild("Timer")
    m.badgeProbeTimer.duration = 1
    m.badgeProbeTimer.repeat = true
    m.badgeProbeTimer.observeField("fire", "runCatchupBadgeProbe")
    m.badgeProbeTimer.control = "start"
end sub

sub runCatchupBadgeProbe()
    if not m.ready or not m.top.active then return
    if m.top.catchupPermission <> "allowed" then return
    chosen = -1
    for i = 0 to m.filtered.count() - 1
        if catchupChannelDays(m.top.catchupPermission, m.top.channelFacts, m.filtered[i].id) > 0
            cells = rowCells(m.filtered[i])
            for each cell in cells
                if cell.program <> invalid
                    chosen = i
                    program = cell.program
                    exit for
                end if
            end for
            if chosen >= 0 then exit for
        end if
    end for
    if chosen < 0 then return
    oldSelected = m.selected
    oldStart = m.rowStart
    oldLayout = m.settings.groupLayout
    m.selected = chosen
    m.rowStart = chosen
    for each layout in ["modal", "sidebar", "pills"]
        m.settings.groupLayout = layout
        drawGuide()
        print "[catchup-badge] layout="; layout; " badge="; m.rows[0].catchup.visible; " numberWidth="; m.rows[0].number.width
    end for
    m.detailChannel = m.filtered[chosen]
    m.detailProgram = program
    updateRichDetails()
    print "[catchup-badge] details="; m.details.model.catchupRetention
    m.top.catchupPermission = "denied"
    onCatchupCapabilities()
    updateRichDetails()
    print "[catchup-badge] denied-hidden="; not m.rows[0].catchup.visible; " details-cleared="; m.details.model.catchupRetention = ""
    m.top.catchupPermission = "allowed"
    savedFacts = m.top.channelFacts
    m.top.channelFacts = {}
    onCatchupCapabilities()
    print "[catchup-badge] missing-facts-hidden="; not m.rows[0].catchup.visible
    m.top.channelFacts = savedFacts
    m.settings.groupLayout = oldLayout
    m.selected = oldSelected
    m.rowStart = oldStart
    drawGuide()
    m.badgeProbeTimer.control = "stop"
    print "[catchup-badge] complete"
end sub
