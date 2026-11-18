' Credential verification only. No lineup/App Data reads, registry writes,
' activation or implicit Sync opt-in. Result proofs contain transient own keys.
sub init()
    m.top.functionName = "verifyPhoneSetupProfiles"
end sub

sub verifyPhoneSetupProfiles()
    m.key = ""
    m.proofs = {}
    m.credentials = {}
    m.rows = []
    m.defaultCredential = invalid
    m.rawProfiles = []
    if type(m.top.profiles) = "roArray" then m.rawProfiles = m.top.profiles
    m.singleAttempt = true
    m.maxResponseBytes = 65536
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 115000
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.requestMode = dispatcharrHeaderMode(textValue(m.top.authMode))
    m.requestUserAgent = dispatcharrUserAgent(textValue(m.top.userAgent))
    if phoneProfileVerificationCancelled() or m.base = "" or userProfileLocalId(m.top.captureNonce) = "" then finishPhoneProfileVerification({ok: false}) : return
    m.defaultCredential = phoneSetupCredential(m.top.defaultCredential)
    if m.defaultCredential = invalid then finishPhoneProfileVerification({ok: false}) : return
    for each raw in m.rawProfiles
        row = phoneSetupProfile(raw)
        if row = invalid then finishPhoneProfileVerification({ok: false}) : return
        if type(row.credential) = "roAssociativeArray" then m.credentials[lcase(row.username)] = row.credential
        row.delete("credential")
        m.rows.push(row)
    end for
    ordered = phoneSetupProfileQueue(m.rows)
    if not ordered.ok then finishPhoneProfileVerification({ok: false}) : return
    expected = textValue(m.defaultCredential.username)
    if ordered.defaultRow <> invalid then expected = ordered.defaultRow.username
    if ordered.defaultRow = invalid and m.rows.count() = 1 then expected = m.rows[0].username
    baseProof = m.top.verifiedDefault
    ' A native optional assocarray field can be an empty map, not invalid.
    ' Empty means no prior proof: authenticate the supplied own credential.
    ' Nonempty but invalid proof still takes the strict refusal path below.
    if type(baseProof) = "roAssociativeArray"
        if baseProof.count() = 0 then baseProof = invalid
    end if
    if type(baseProof) = "roAssociativeArray"
        facts = userProfileFromVerified("verified", "00000000-0000-4000-8000-000000000001", baseProof.verifiedUser, 1)
        if facts = invalid or baseProof.ok <> true or baseProof.verifiedBaseUrl <> m.base or textValue(baseProof.apiKey) = "" then finishPhoneProfileVerification({ok: false}) : return
        if expected <> "" and lcase(facts.username) <> lcase(expected) then finishPhoneProfileVerification({ok: false}) : return
    else
        baseProof = verifyPhoneProfileCredential(m.defaultCredential, expected)
    end if
    if baseProof.ok <> true then finishPhoneProfileVerification({ok: false, rateLimited: baseProof.rateLimited = true}) : return
    baseName = baseProof.verifiedUser.username
    m.proofs[lcase(baseName)] = baseProof
    if ordered.defaultRow = invalid
        for i = 0 to m.rows.count() - 1
            if lcase(m.rows[i].username) = lcase(baseName)
                m.rows[i] = setCanonicalPreference(m.rows[i], "isDefault", true)
                exit for
            end if
        end for
        ordered = phoneSetupProfileQueue(m.rows)
    end if
    parked = false
    for each item in ordered.queue
        if m.top.defaultOnly = true then exit for
        if phoneProfileVerificationCancelled() then finishPhoneProfileVerification({ok: false}) : return
        username = item.row.username
        if username.trim() <> "" and not m.proofs.doesExist(lcase(username)) and m.proofs.count() < 4
            proof = verifyPhoneProfileCredential(m.credentials[lcase(username)], username)
            if proof.rateLimited = true or proof.requestGateReason = "parked"
                parked = true
                exit for
            end if
            if proof.ok = true then m.proofs[lcase(username)] = proof
        end if
    end for
    finishPhoneProfileVerification({ok: true, nonce: m.top.captureNonce, baseUsername: baseName, rows: m.rows, proofs: m.proofs, rateLimited: parked})
end sub

function phoneProfileVerificationCancelled() as boolean
    return m.top.cancelRequested = true or not requestGateTaskSessionCurrent()
end function

function verifyPhoneProfileCredential(credential as dynamic, expected as string) as object
    if type(credential) <> "roAssociativeArray" then return {ok: false}
    hasPassword = textValue(credential.password) <> "" and expected <> ""
    attempt = "password"
    if textValue(credential.apiKey) <> "" then attempt = "key"
    result = verifyPhoneProfileAttempt(credential, expected, attempt)
    if phoneSetupProfileNextAttempt(attempt, hasPassword, result) = "password" then result = verifyPhoneProfileAttempt(credential, expected, "password")
    wipePhoneProfileCredential(credential)
    return result
end function

function verifyPhoneProfileAttempt(credential as object, expected as string, attempt as string) as object
    if phoneProfileVerificationCancelled() then return {ok: false}
    m.key = ""
    m.httpFailure = invalid
    user = invalid
    if attempt = "key"
        m.key = textValue(credential.apiKey)
        if m.key = "" then return {ok: false}
        user = requestJson(m.base + "/api/accounts/users/me/")
    else
        password = textValue(credential.password)
        if expected = "" or password = "" then return {ok: false}
        body = {username: expected, password: password}
        password = ""
        credential.password = ""
        token = requestJson(m.base + "/api/accounts/token/", body)
        body.password = ""
        if type(token) = "roAssociativeArray"
            access = textValue(token.access)
            token = invalid
            if access <> "" then user = requestJson(m.base + "/api/accounts/users/me/", invalid, access)
            access = ""
        end if
        if type(user) = "roAssociativeArray" then m.key = textValue(user.api_key)
    end if
    if phoneProfileVerificationCancelled() then m.key = "" : return {ok: false}
    if type(user) <> "roAssociativeArray"
        m.key = ""
        failure = {ok: false, relogin: httpAccountRejected(m.httpFailure)}
        if type(m.httpFailure) = "roAssociativeArray"
            if m.httpFailure.status = 429 then failure.rateLimited = true
            if textValue(m.httpFailure.gateReason) <> "" then failure.requestGateReason = m.httpFailure.gateReason
        end if
        return failure
    end if
    if expected <> "" and lcase(textValue(user.username)) <> lcase(expected)
        m.key = ""
        return {ok: false, identityChanged: true}
    end if
    facts = userProfileFromVerified("verified", "00000000-0000-4000-8000-000000000001", user, 1)
    if facts = invalid or m.key = "" or len(m.key) > 512 then m.key = "" : return {ok: false}
    result = {ok: true, verifiedBaseUrl: m.base, apiKey: m.key, verifiedUser: {id: facts.userId, username: facts.username, user_level: facts.userLevel, is_staff: facts.isStaff, is_superuser: facts.isSuperuser}}
    user = invalid
    m.key = ""
    return result
end function

sub wipePhoneProfileCredential(credential as dynamic)
    if type(credential) <> "roAssociativeArray" then return
    for each key in credential
        if lcase(key) = "apikey" or lcase(key) = "password" then credential[key] = ""
    end for
end sub

sub finishPhoneProfileVerification(result as object)
    wipePhoneProfileCredential(m.defaultCredential)
    wipePhoneProfileCredential(m.top.defaultCredential)
    for each username in m.credentials
        wipePhoneProfileCredential(m.credentials[username])
    end for
    for each row in m.rawProfiles
        if type(row) = "roAssociativeArray" then wipePhoneProfileCredential(row.credential)
    end for
    if phoneProfileVerificationCancelled() or result.ok <> true
        for each username in m.proofs
            m.proofs[username].apiKey = ""
        end for
        result = {ok: false, rateLimited: result.rateLimited = true}
    end if
    m.key = ""
    m.credentials = {}
    m.rawProfiles = []
    m.defaultCredential = invalid
    m.top.defaultCredential = invalid
    m.top.verifiedDefault = invalid
    m.top.profiles = []
    m.proofs = {}
    m.top.result = result
end sub
