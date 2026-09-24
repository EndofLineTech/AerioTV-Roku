sub init()
    m.top.functionName = "loadPermittedProfiles"
end sub

sub loadPermittedProfiles()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.requestMode = dispatcharrHeaderMode(textValue(m.top.authMode))
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 45000
    m.maxResponseBytes = 2097152
    account = requestJson(m.base + "/api/accounts/users/me/")
    if type(account) <> "roAssociativeArray" and m.requestMode <> "x-api-key"
        if type(m.httpFailure) = "roAssociativeArray"
            if m.httpFailure.status = 400
                m.requestMode = "x-api-key"
                account = requestJson(m.base + "/api/accounts/users/me/")
            end if
        end if
    end if
    if type(account) <> "roAssociativeArray"
        finishProfiles({ok: false, message: "Could not verify this account's profile access. " + m.failure})
        return
    end if
    id = textValue(account.id)
    if id = "" or (m.top.accountId <> "" and id <> m.top.accountId)
        finishProfiles({ok: false, message: "Account changed. Reconnect before selecting a profile."})
        return
    end if
    rows = requestPages("/api/channels/profiles/?page=1&page_size=200")
    if rows = invalid
        finishProfiles({ok: false, message: "Could not load permitted channel profiles. " + m.failure})
        return
    end if
    finishProfiles({ok: true, accountId: id, authModeUsed: m.requestMode, choices: profileChoiceList(rows, m.top.profileId)})
end sub

sub finishProfiles(result as object)
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested <> true then m.top.result = result
end sub
