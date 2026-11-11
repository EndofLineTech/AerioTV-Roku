' ALL gallery Task components use this code instead of production I/O scripts.
' Only synthetic read responses are allowed. Any mutation/unexpected Task is
' reported as forbidden and makes the host runner fail; no I/O API exists here.
sub init()
    m.top.functionName = "runUiAuditFixtureTask"
end sub

sub runUiAuditFixtureTask()
    scenario = m.global.uiAuditLibraryCase
    if scenario = invalid then scenario = ""
    kind = m.top.subtype()
    if instr(1, scenario, "loading") > 0
        for i = 1 to 150
            sleep(100)
            if m.top.cancelRequested then return
        end for
    end if
    if kind = "VodTask" or kind = "XtreamVodTask" or kind = "VodShelfTask"
        operation = "page"
        if m.top.hasField("operation") then operation = m.top.operation
        media = "movie"
        if m.top.hasField("kind") then media = m.top.kind
        if media = "" then media = "movie"
        page = 1
        if m.top.hasField("pageNumber") then page = m.top.pageNumber
        itemId = ""
        if m.top.hasField("itemId") then itemId = m.top.itemId
        m.top.result = uiAuditVodResult(media, operation, page, itemId, scenario)
    else if kind = "DvrRecordingTask"
        action = m.top.action
        if action <> "list" and action <> "series-list"
            print "[ui-audit] "; formatJson({forbidden: true, task: kind, action: action})
            m.top.result = {ok: false, accountId: "fixture", message: "Gallery blocks all mutations."}
            return
        end if
        result = {ok: true, accountId: "fixture", recordings: uiAuditRecordings(scenario), rules: uiAuditRules(scenario)}
        if scenario = "dvr-error" or scenario = "dvr-denied" or (scenario = "dvr-rule-error" and action = "series-list")
            result.ok = false
            result.message = "Synthetic recording service unavailable (503)."
            if scenario = "dvr-denied" then result.message = "Synthetic permission denied (403)."
        end if
        m.top.result = result
    else
        print "[ui-audit] "; formatJson({forbidden: true, task: kind})
    end if
end sub
