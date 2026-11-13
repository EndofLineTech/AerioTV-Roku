sub main()
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Synthetic7", user_level: 1}, 1)
    store = defaultUserProfileStore("slot-a")
    store.profiles = [profile]
    store.active = profile.id
    m.userProfileStore = normalizeUserProfileStore(store, "slot-a")
    m.registry = {data: FormatJson(store), exists: function(key as string) as boolean
        return left(key, 15) = "userProfilesV1_"
    end function, read: function(key as string) as string
        return m.data
    end function}
    m.profileManagementSlot = "slot-a"
    m.selectedConnectionId = "slot-a"
    m.profileManagementNonce = "00000000-0000-4000-8000-000000000090"
    m.profileManagementDialogNonce = m.profileManagementNonce
    m.profileManagementDialog = {id: "current", close: false, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, unobserveField: sub(field as string)
    end sub}
    event = {node: m.profileManagementDialog, getRoSGNode: function() as object
        return m.node
    end function}
    check(profileManagementContextCurrent() and profileManagementEventCurrent(event), "current metadata dialog belongs to captured profile and lifecycle")
    m.selectedConnectionId = "slot-b"
    check(not profileManagementEventCurrent(event), "other slot cannot submit an old metadata dialog")
    m.selectedConnectionId = "slot-a"
    m.profileManagementNonce = "00000000-0000-4000-8000-000000000091"
    check(not profileManagementEventCurrent(event), "same-slot A/B/A lifecycle cannot resurrect old dialog events")
    m.profileManagementNonce = m.profileManagementDialogNonce
    event.node = {id: "old"}
    check(not profileManagementEventCurrent(event), "replaced dialog node refuses even under current lifecycle")
    dialog = m.profileManagementDialog
    m.profileManagementGrant = {kind: "pin"}
    m.profileManagementPending = {id: profile.id}
    m.profileManagementChoices = [{title: "Sensitive other identity"}]
    retireProfileManagement()
    check(dialog.close and m.profileManagementDialog = invalid and m.profileManagementGrant = invalid and m.profileManagementPending = invalid and m.profileManagementNonce = "" and m.profileManagementChoices.count() = 0, "connection retirement closes dialogs and clears grants, pending work and identity labels")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
