sub main()
    resetTask("list")
    m.responses = [admin(), sources(), status("old", "roku")]
    runSourceOperation()
    assertEqual(m.top.result.ok, true, "list succeeds")
    assertEqual(m.posts, 0, "listing never mutates server")
    assertEqual(m.calls.count(), 3, "identity, membership, status")
    assertEqual(m.top.apiKey, "", "Task credential cleared")

    resetTask("switch")
    m.responses = [admin(), sources(), status("old", "roku"), {url: "https://provider/new"}, status("new", "roku")]
    runSourceOperation()
    assertEqual(m.top.result.ok, true, "actual Task confirms URL switch")
    assertEqual(m.posts, 1, "exactly one mutation")
    assertEqual(m.postBody.stream_id, 11, "numeric member stream ID")
    assertEqual(m.calls[3], "http://server.test/proxy/ts/change_stream/abc-123", "supported mutation route")
    assertEqual(m.top.result.continuity.state, "preserved", "original client retained")
    assertEqual(instr(1, FormatJson(m.top.result), "https://provider"), 0, "provider URL does not escape Task")

    resetTask("switch")
    m.responses = [admin(), sources(), status("old", "roku"), {url: "https://provider/new"}, status("new", "replacement")]
    runSourceOperation()
    assertEqual(m.top.result.ok, true, "source success remains distinct from continuity")
    assertEqual(m.top.result.continuity.state, "changed", "replacement client detected by actual Task")

    resetTask("switch")
    m.responses = [admin(), sources(), status("new", "roku")]
    runSourceOperation()
    assertEqual(m.top.result.unchanged, true, "URL-confirmed active source is a no-op despite stale reported ID")
    assertEqual(m.posts, 0, "active source is never needlessly restarted")

    resetTask("switch")
    m.responses = [{id: 7, user_level: 1}]
    runSourceOperation()
    assertEqual(m.top.result.ok, false, "revoked permission rejected")
    assertEqual(m.posts, 0, "no POST after permission revocation")

    resetTask("switch")
    m.responses = [{id: 8, user_level: 10}]
    runSourceOperation()
    assertEqual(m.top.result.ok, false, "different admin identity rejected")
    assertEqual(m.posts, 0, "identity changes cannot mutate")

    resetTask("switch")
    m.top.streamId = "99"
    m.responses = [admin(), sources(), status("old", "roku")]
    runSourceOperation()
    assertEqual(m.top.result.ok, false, "stale member rejected")
    assertEqual(m.posts, 0, "no mutation of a non-member source")

    resetTask("switch")
    m.responses = [admin(), sources(), status("old", "roku"), invalid]
    runSourceOperation()
    assertEqual(m.top.result.ok, false, "failed POST reported")
    assertEqual(m.posts, 1, "failed mutation is not retried")

    resetTask("switch")
    m.expireAfterPost = true
    m.responses = [admin(), sources(), status("old", "roku"), {url: "https://provider/new"}]
    runSourceOperation()
    assertEqual(m.top.result.ok, false, "deadline without confirmation is not success")
    assertEqual(m.calls.count(), 4, "confirmation cannot exceed overall deadline")

    resetTask("unsupported")
    runSourceOperation()
    assertEqual(m.calls.count(), 0, "unknown operations rejected before network")
    resetTask("switch")
    m.top.streamId = "11?bad"
    runSourceOperation()
    assertEqual(m.calls.count(), 0, "invalid source rejected before network")
    print "ALL TESTS PASSED"
end sub

sub resetTask(operation as string)
    m.top = {baseUrl: "http://server.test", apiKey: "test-key", accountId: "7", channelId: "4", channelUuid: "abc-123", streamId: "11", operation: operation}
    m.responses = []
    m.calls = []
    m.posts = 0
    m.expireAfterPost = false
end sub

function admin() as object
    return {id: 7, user_level: 10}
end function

function sources() as object
    return [{id: 10, name: "A", url: "https://provider/old"}, {id: 11, name: "B", url: "https://provider/new"}]
end function

function status(source as string, client as string) as object
    return {url: "https://provider/" + source, stream_id: 10, client_count: 1, clients: [{client_id: client}]}
end function

' Scripted HTTP boundary around the actual Task body; no native network emulation.
function requestJson(url as string, body = invalid as dynamic, bearer = "" as string) as dynamic
    m.calls.push(url)
    if body <> invalid
        m.posts++
        m.postBody = body
        if m.expireAfterPost
            m.clock = {totalMilliseconds: function() as integer
                return 31000
            end function}
        end if
    end if
    m.failure = "Scripted HTTP failure."
    if m.responses.count() = 0 then return invalid
    return m.responses.shift()
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
