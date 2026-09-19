sub init()
    m.top.functionName = "searchPrograms"
end sub

sub searchPrograms()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    params = programSearchParameters(m.top.query, m.top.searchField, m.top.page, m.top.now)
    result = {ok: false, items: [], hasNext: false, message: "Enter at least two characters."}
    if params <> invalid
        encoder = CreateObject("roUrlTransfer")
        path = "/api/epg/programs/search/?" + params.field + "=" + encoder.escape(params.query) + "&end_after=" + encoder.escape(params.endAfter) + "&start_before=" + encoder.escape(params.startBefore) + "&page=" + params.page.toStr() + "&page_size=" + params.pageSize.toStr() + "&fields=id,title,sub_title,description,start_time,end_time,tvg_id,channels"
        payload = requestJson(m.base + path)
        rows = apiRows(payload)
        if rows = invalid
            result.message = "Program search unavailable. " + m.failure
        else
            normalized = programSearchResults(rows, m.top.channels, m.top.now)
            result = {ok: true, items: normalized.items, truncated: normalized.truncated, hasNext: false, message: ""}
            if type(payload) = "roAssociativeArray" then result.hasNext = textValue(payload.next) <> ""
            ' Rebuild pagination paths ourselves; never follow arbitrary next URLs.
        end if
    end if
    m.key = ""
    m.top.apiKey = ""
    m.top.channels = []
    m.top.result = result
end sub
