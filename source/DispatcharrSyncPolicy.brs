' Sanitized sync outcomes only. Key rejection/429 admission stays in the shared
' broker; no arbitrary response JSON, header, raw credential or URL is returned.
function dispatcharrSyncFailure(phase as string, status as integer, code as string, transportError as string) as object
    state = "retry"
    if transportError = ""
        if status = 401 or status = 403
            if phase = "me" then state = "authorization-unavailable"
            if phase = "list" or phase = "put" then state = "signin-required"
        else if status = 429
            state = "parked"
        else if phase = "put" and status = 409 and code = "max_apps"
            state = "storage-full"
        else if phase = "put" and status = 413
            if code = "value_too_large" or code = "body_too_large" or code = "total_too_large" then state = "too-large"
        end if
    end if
    return {ok: false, state: state, phase: phase, status: status, submitted: phase = "put"}
end function
