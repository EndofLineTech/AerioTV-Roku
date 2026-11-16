sub main()
    base = {id: 1, username: "base", user_level: 10}
    actor = {id: 2, username: "actor", user_level: 1, is_staff: true}
    check(userProfileServerAdminAllowed(base, actor, "user"), "both live server admin proofs allow Standard local management")
    check(not userProfileServerAdminAllowed(base, {id: 2, username: "actor", user_level: 1}, "admin"), "local Admin label cannot invent server authority")
    check(not userProfileServerAdminAllowed(invalid, actor, "admin"), "missing base-login proof refuses")
    check(not userProfileServerAdminAllowed(base, actor, "child"), "Child refuses even with server admin facts")
    target = {id: 3, username: "target", api_key: ""}
    generated = userProfileServerAdminMutation("generate", target, actor, invalid, [], false)
    check(generated.ok and generated.path = "/api/accounts/api-keys/generate/" and generated.body.user_id = 3, "generation always names explicit missing-key target")
    target.api_key = "existing"
    check(not userProfileServerAdminMutation("generate", target, actor, invalid, [], false).ok, "existing target key is never rotated")
    target.api_key = ""
    omitted = {id: 3, username: "target"}
    check(not userProfileServerAdminMutation("generate", omitted, actor, invalid, [], false).ok, "an omitted API-key field is not proof that generation is safe")
    check(not userProfileServerAdminMutation("generate", actor, actor, invalid, [], false).ok, "caller key is never generated or revoked through another-user controls")
    minted = {id: 3, username: "target", key: "minted-here"}
    target.api_key = "minted-here"
    check(not userProfileServerAdminMutation("revoke", target, actor, minted, [], false).ok, "revoke requires explicit confirmation")
    revoked = userProfileServerAdminMutation("revoke", target, actor, minted, [], true)
    check(revoked.ok and revoked.body.user_id = 3, "confirmed revoke names only same-session minted holder")
    target.api_key = "replaced-elsewhere"
    check(not userProfileServerAdminMutation("revoke", target, actor, minted, [], true).ok, "server replacement cannot be revoked using old minted proof")
    channels = userProfileServerAdminMutation("channels", target, actor, invalid, [4, 7], true)
    check(channels.ok and channels.method = "PATCH" and channels.path = "/api/accounts/users/3/" and channels.body.channel_profiles.count() = 2, "Channel Profiles PATCH is explicit-user integer array")
    check(userProfileServerAdminMutation("channels", target, actor, invalid, [], true).ok, "empty Channel Profiles means All")
    check(not userProfileServerAdminMutation("channels", target, actor, invalid, ["4"], true).ok, "string or malformed IDs cannot enter PATCH")
    offered = userProfileServerAdminCandidates([base, actor, target], [{username: "BASE"}], [{username: "Target"}])
    check(offered.count() = 1 and offered[0].username = "actor", "other-users list omits local and roster suggestions case-insensitively")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
