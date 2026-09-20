' Task-thread-only helpers. Never include this script in a rendering component.
function requestPages(path as string) as dynamic
    m.pagesClock = CreateObject("roTimespan")
    m.pagesClock.mark()
    result = requestPagedRows(path)
    m.pagesClock = invalid
    return result
end function

function requestPagedRows(path as string) as dynamic
    url = m.base + path
    rows = []
    visited = {}
    while url <> ""
        if m.progressLabel <> invalid then m.top.progress = m.progressLabel + " - page " + (visited.count() + 1).toStr()
        if visited.doesExist(url) or visited.count() >= 100
            m.failure = "Pagination repeated or exceeded 100 pages."
            return invalid
        end if
        visited[url] = true
        payload = requestJson(url)
        page = apiRows(payload)
        if page = invalid
            if m.failure = "" then m.failure = "The server did not return a JSON list."
            return invalid
        end if
        if rows.count() + page.count() > 100000
            m.failure = "Metadata list exceeds the 100,000-row loading limit. Use paged browsing."
            return invalid
        end if
        rows.append(page)
        url = ""
        if type(payload) = "roAssociativeArray"
            nextPage = textValue(payload.next)
            if nextPage <> ""
                url = trustedPageUrl(m.base, nextPage)
                if url = ""
                    m.failure = "The server returned an unexpected pagination URL."
                    return invalid
                end if
            end if
        end if
    end while
    return rows
end function

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string) as dynamic
    m.failure = ""
    m.httpFailure = invalid
    m.httpAttempts = 0
    timeout = 20000
    if m.timeout <> invalid then timeout = m.timeout
    if m.deadlineMs <> invalid
        remaining = m.deadlineMs - m.clock.totalMilliseconds()
        if remaining < timeout then timeout = remaining
    end if
    if m.pagesClock <> invalid
        remaining = 60000 - m.pagesClock.totalMilliseconds()
        if remaining < timeout then timeout = remaining
    end if
    maxBytes = 8388608
    if m.maxResponseBytes <> invalid then maxBytes = m.maxResponseBytes
    clock = CreateObject("roTimespan")
    clock.mark()
    for attempt = 0 to 1
        if httpIsCancelled()
            setHttpFailure(httpFailure(0, {}, 0, "cancelled"))
            return invalid
        end if
        remaining = timeout - clock.totalMilliseconds()
        if remaining <= 0
            setHttpFailure(httpFailure(0, {}, 0, "timeout"))
            return invalid
        end if
        m.httpAttempts++
        response = httpTransferOnce(url, body, bearer, remaining, maxBytes)
        if response.error = "" and response.status >= 200 and response.status < 300
            if len(response.body) > maxBytes
                setHttpFailure(httpFailure(0, {}, 0, "too-large"))
                return invalid
            end if
            if not CreateObject("roRegex", "^\s*[\{\[]", "").isMatch(response.body)
                setHttpFailure(httpFailure(response.status, {}, 0, "invalid-response"))
                return invalid
            end if
            value = ParseJson(response.body)
            if value = invalid then setHttpFailure(httpFailure(response.status, {}, 0, "invalid-response"))
            return value
        end if
        failure = httpFailure(response.status, response.headers, CreateObject("roDateTime").asSeconds(), response.error)
        setHttpFailure(failure)
        ' Never auto-repeat login/source-switch/catch-up mutations.
        if body <> invalid or attempt > 0 or not failure.retryable then return invalid
        delay = failure.retryAfter
        if delay < 0 then delay = 1
        remaining = timeout - clock.totalMilliseconds()
        if delay > 60 or delay * 1000 >= remaining then return invalid
        pause = CreateObject("roTimespan")
        pause.mark()
        port = CreateObject("roMessagePort")
        while pause.totalMilliseconds() < delay * 1000
            if httpIsCancelled()
                setHttpFailure(httpFailure(0, {}, 0, "cancelled"))
                return invalid
            end if
            wait(50, port)
        end while
        m.failure = ""
        m.httpFailure = invalid
    end for
    return invalid
end function

sub setHttpFailure(failure as object)
    m.httpFailure = failure
    m.failure = failure.message
end sub

function httpIsCancelled() as boolean
    if type(m.top) = "roAssociativeArray" then return m.top.cancelRequested = true
    if m.top <> invalid
        if m.top.hasField("cancelRequested") then return m.top.cancelRequested
    end if
    return false
end function
