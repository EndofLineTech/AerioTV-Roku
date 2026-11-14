sub main()
    childRejectedFixture(false)
    check(showChildRejectedKeyPrompt(), "admitted refused nondefault Child gets its own bound rejection dialog")
    check(m.fixtureUnavailableClosed and m.childRejectedDialog.title = "API key no longer valid" and m.childRejectedDialog.buttons.count() = 1 and m.childRejectedDialog.buttons[0] = "Not Now", "Child prompt replaces only the unavailable node and never exposes an own form or another profile")
    check(m.childRejectedDialog.message = "Dispatcharr no longer accepts the API key for Synthetic. It may have been changed on the server.", "active nondefault Child body is cut exactly without extra instructions")
    first = m.childRejectedDialog
    onChildRejectedKeyChoice(childRejectedEvent(first, 0))
    check(m.fixtureSurface and not m.fixtureSignedIn and m.childRejectedDialog = invalid and not showChildRejectedKeyPrompt(), "Not Now restores only the Child surface and the same held generation never prompts twice")
    m.childRejectedEvidence.version = 2
    m.requestGate.snapshot.keys[string(64, "a")].version = 2
    check(showChildRejectedKeyPrompt(), "a later same-hash re-rejection gets its own once-only prompt generation")
    current = m.childRejectedDialog
    onChildRejectedKeyChoice(childRejectedEvent(first, 0))
    check(m.childRejectedDialog.isSameNode(current), "retired native rejection nodes cannot dismiss a successor prompt")
    childRejectedFixture(true)
    check(showChildRejectedKeyPrompt() and m.childRejectedDialog.buttons.count() = 2 and m.childRejectedDialog.buttons[0] = "Sign In with Remote", "default Child gets its existing own-account form only under fresh admitted policy")
    onChildRejectedKeyChoice(childRejectedEvent(m.childRejectedDialog, 0))
    check(m.fixtureSignedIn and m.fixtureOwnId = m.fixtureAccess.target.id and m.fixtureOwnActive and m.fixtureOwnChild and m.childRejectedDialog = invalid, "Remote action carries only active-Child own recovery, with no fabricated authenticated scope")
    childRejectedFixture(true)
    showChildRejectedKeyPrompt()
    m.registry.data = "changed-roster-or-PIN"
    onChildRejectedKeyChoice(childRejectedEvent(m.childRejectedDialog, 0))
    check(not m.fixtureSignedIn, "roster/PIN bytes changing under a default Child prompt refuse its stale own-form callback")
    childRejectedFixture(true)
    showChildRejectedKeyPrompt()
    m.fixtureAccess.entry.name = "Changed connection lifecycle"
    onChildRejectedKeyChoice(childRejectedEvent(m.childRejectedDialog, 0))
    check(not m.fixtureSignedIn, "connection replacement under a prompt cannot inherit old own-account admission")
    childRejectedFixture(true)
    showChildRejectedKeyPrompt()
    onChildRejectedKeyClosed(childRejectedEvent(m.childRejectedDialog, 0))
    check(m.fixtureSurface and not m.fixtureSignedIn, "native rejection Back dismisses to Child unavailable, not setup or another identity")
    childRejectedFixture(true)
    m.fixtureAccessAllowed = false
    check(not showChildRejectedKeyPrompt() and m.childRejectedDialog = invalid, "missing launch-PIN/identity access cannot disclose or open a rejected-key form")
    childRejectedFixture(true)
    m.requestGate.snapshot.keys[string(64, "a")].version = 2
    check(not showChildRejectedKeyPrompt(), "old rejected evidence cannot prompt for a successor hold generation")
    childRejectedFixture(true)
    m.requestGate.snapshot = requestGateDefault()
    m.childRejectedEvidence.version = 0
    check(showChildRejectedKeyPrompt(), "bound identity failure with no broker401 hold uses its own memory-only failure lifecycle")
    closeChildRejectedKeyDialog()
    check(not showChildRejectedKeyPrompt(), "one identity-failure lifecycle does not re-prompt after dismissal")
    m.childRejectedEvidence.nonce = "00000000-0000-4000-8000-000000000091"
    check(showChildRejectedKeyPrompt(), "a distinct later identity failure does not inherit an earlier dismissed UI lifecycle")
    childRejectedFixture(false)
    m.profileChildAccessReady = false
    check(not showChildRejectedKeyPrompt(), "shipping Child readiness remains gated during this private controller qualification")
    print "ALL TESTS PASSED"
end sub

sub childRejectedFixture(defaultChild as boolean)
    id = "00000000-0000-4000-8000-000000000002"
    account = 8
    username = "Bob"
    if defaultChild
        id = "00000000-0000-4000-8000-000000000001"
        account = 7
        username = "Alice"
    end if
    entry = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", accountUsername: "Alice", remember: true})
    m.fixtureAccess = {entry: entry, store: {active: id}, target: {id: id, userId: account, username: username, role: "child", isDefault: defaultChild}, plan: {signIn: defaultChild}, keyRejected: true}
    m.fixtureAccessAllowed = true
    m.childRejectedEvidence = {slot: entry.id, base: entry.url, profile: id, account: account.toStr(), username: username, hash: string(64, "a"), version: 1, nonce: "00000000-0000-4000-8000-000000000090"}
    m.childRejectedIdentity = entry.url + "|slot-a|" + id
    state = requestGateDefault()
    state.keys[string(64, "a")] = {version: 1}
    m.requestGate = {snapshot: state}
    m.registry = {data: "roster-v1", read: function(key as string) as string
        return m.data
    end function}
    m.profileChildAccessReady = true
    m.profileOwnSignInContext = invalid
    m.profileSwitchContext = invalid
    m.childRejectedDialog = invalid
    m.childRejectedContext = invalid
    m.childRejectedShown = {}
    m.selectedConnectionId = entry.id
    m.page = "profile-unavailable"
    m.activeUserScope = invalid
    m.apiKey = ""
    m.global = {profilegateclosed: true}
    m.top = {}
    m.factorySequence = 0
    m.childRejectedDialogFactory = function() as object
        m.factorySequence++
        return {id: m.factorySequence, isSameNode: function(other as object) as boolean
            return m.id = other.id
        end function, observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub, setFocus: sub(focus as boolean)
        end sub}
    end function
    m.fixtureUnavailableClosed = false
    m.fixtureSurface = false
    m.fixtureSignedIn = false
end sub

function unavailableChildAccessContext() as dynamic
    if not m.fixtureAccessAllowed then return invalid
    return m.fixtureAccess
end function

sub closeUnavailableChildDialog()
    m.fixtureUnavailableClosed = true
end sub

function showUnavailableChildProfile() as boolean
    m.fixtureSurface = true
    return true
end function

function beginUserProfileOwnSignIn(id as string, activeRecovery as boolean, childRecovery as boolean) as boolean
    m.fixtureSignedIn = true
    m.fixtureOwnId = id
    m.fixtureOwnActive = activeRecovery
    m.fixtureOwnChild = childRecovery
    return true
end function

function childRejectedEvent(node as object, choice as integer) as object
    return {node: node, choice: choice, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.choice
    end function}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
