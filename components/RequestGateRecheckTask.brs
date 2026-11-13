' Only the active binding is scheduled. Inactive stored profiles are never
' enumerated or validated. The broker atomically consumes the slow-probe slot.
sub init()
    m.top.functionName = "recheckHeldKey"
end sub

sub recheckHeldKey()
    m.key = m.top.apiKey
    url = normalizeBaseUrl(m.top.baseUrl) + "/api/accounts/users/me/"
    permit = requestGateAcquire(url, m.key, true)
    ok = false
    if permit.allowed
        if permit.probe and not m.top.cancelRequested
            response = httpTransferPermitted(url, invalid, "", 5000, 65536, "GET", invalid, permit)
            if response.status >= 200 and response.status < 300 and response.error = ""
                if CreateObject("roRegex", "^\s*\{", "").isMatch(response.body)
                    ok = requestGateProbeIdentityMatches(ParseJson(response.body, "d"), m.top.accountId)
                end if
                ' A proxy HTML/empty/different-user 200 is not authentication.
                if not ok then response.status = 0
            end if
            requestGateReport(permit, response)
        else
            requestGateRelease(permit)
        end if
    end if
    m.key = ""
    m.top.apiKey = ""
    m.top.result = {ok: ok}
end sub
