sub main()
    prompt = {unobserved: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub}
    recheck = {unobserved: false, cancelRequested: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub}
    m.requestGatePrompt = prompt
    m.requestGateRecheck = recheck
    m.requestGateBinding = {slot: "slot-a", key: "retired-key"}
    retireProfileRequestBinding()
    check(prompt.unobserved and recheck.unobserved and recheck.cancelRequested, "profile retirement detaches prompt and cancels owned recheck")
    check(m.requestGatePrompt = invalid and m.requestGateRecheck = invalid and m.requestGateBinding = invalid, "same-slot A/B/A cannot revive an outgoing raw-key binding")
    m.global = {profileswitchpending: true}
    rememberHeldRequestGateBinding()
    check(m.requestGateBinding = invalid, "broker snapshots cannot recreate an outgoing binding under the incoming staging session")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
