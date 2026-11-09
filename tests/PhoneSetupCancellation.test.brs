sub main()
    ' No SG node at all: checking cancellation must not touch m.top, since
    ' synchronous field reads can depend on a suspended render thread.
    m.top = invalid
    m.cancelled = false
    m.setupPort = {
        remaining: 0, reads: 0
        getMessage: function() as dynamic
            m.reads++
            if m.remaining = 0 then return invalid
            m.remaining--
            return {} ' Socket notifications do not carry cancellation state.
        end function
    }
    check(not phoneSetupCancelled(), "no field read required while idle")
    check(m.setupPort.reads = 1, "empty port is non-blocking")
    m.setupPort.remaining = 40
    m.setupPort.reads = 0
    check(not phoneSetupCancelled(), "socket events do not cancel a session")
    check(m.setupPort.reads = 32 and m.setupPort.remaining = 8, "notification drain bounded even under socket traffic")
    check(not phoneSetupCancelled() and m.setupPort.remaining = 0, "remaining notifications handled on next check")
    m.cancelled = true
    phoneSetupObserveEvent(invalid)
    check(phoneSetupCancelled(), "cancelled state is sticky and independent of SG reads")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, message as string)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub
