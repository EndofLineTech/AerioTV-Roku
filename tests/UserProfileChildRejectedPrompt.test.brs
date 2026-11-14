sub main()
    child = {role: "child", isDefault: false}
    body = "Dispatcharr no longer accepts the API key for Synthetic. It may have been changed on the server."
    prompt = userProfileChildRejectedPrompt(child, "Synthetic", false)
    check(prompt.title = "API key no longer valid" and prompt.message = body and prompt.buttons.count() = 1 and prompt.buttons[0] = "Not Now", "nondefault Child rejection uses the exact cut protocol body and no own Sign In")
    prompt = userProfileChildRejectedPrompt(child, "Synthetic", true)
    check(prompt.message = body and prompt.buttons.count() = 1, "even a forged own-form permission cannot offer Sign In to an active refused nondefault Child")
    child.isDefault = true
    prompt = userProfileChildRejectedPrompt(child, "Synthetic", true)
    check(prompt.message = body + " Sign in with your Dispatcharr username and password to reconnect." and prompt.buttons.count() = 2 and prompt.buttons[0] = "Sign In with Remote" and prompt.buttons[1] = "Not Now", "default Child offered its own form gets only the prescribed extended body and Remote/Not Now order")
    prompt = userProfileChildRejectedPrompt(child, "Synthetic", false)
    check(prompt.message = body and prompt.buttons.count() = 1, "without own identity/PIN admission even a default Child gets no form invitation")
    child.role = "user"
    check(userProfileChildRejectedPrompt(child, "Synthetic", true) = invalid, "Child prompt policy is not a generic setup or adult-profile route")
    check(userProfileChildRejectedPrompt(invalid, "Synthetic", false) = invalid, "missing profile authority has no rejected-key UI plan")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
