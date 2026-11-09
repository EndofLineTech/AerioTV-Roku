' Preparation only: callers must verify the chosen identity with the provider
' before matching/committing. Never infer server permissions from profile roles.
function phoneSetupEffectiveCredential(payload as object) as dynamic
    chosen = payload.playlist.credential
    if chosen = invalid
        profiles = payload.profiles
        if type(profiles) <> "roArray" then return invalid
        defaultProfile = invalid
        for each profile in profiles
            if profile.isDefault = true
                if defaultProfile <> invalid then return invalid
                defaultProfile = profile
            end if
        end for
        if defaultProfile = invalid and profiles.count() = 1 then defaultProfile = profiles[0]
        if defaultProfile = invalid then return invalid
        chosen = defaultProfile.credential
    end if
    validated = phoneSetupCredential(chosen)
    if validated = invalid then return invalid
    result = {apiKey: "", username: "", password: ""}
    result.append(validated)
    return result
end function

' Stage a verified candidate only; registry/credential persistence is a separate
' transaction owned by the future apply controller. No input object is changed.
function phoneSetupStageVerifiedConnection(store as object, candidate as object, choice as string, matchedId as string) as dynamic
    if store.readOnly = true or choice = "cancel" then return invalid
    staged = normalizeConnectionStore(store)
    if staged.readOnly = true then return invalid
    entry = normalizeConnectionEntry(candidate)
    if entry = invalid then return invalid
    matches = phoneSetupDuplicateIds(staged, entry)
    if choice = "replace"
        matched = false
        for each id in matches
            if id = matchedId then matched = true
        end for
        if not matched then return invalid
        for i = 0 to staged.entries.count() - 1
            if staged.entries[i].id = matchedId
                entry.id = matchedId
                staged.entries[i] = entry
                staged.selected = matchedId
                return staged
            end if
        end for
        return invalid
    end if
    if choice <> "add" and choice <> "addAnyway" then return invalid
    if choice = "add" and matches.count() > 0 then return invalid
    if staged.entries.count() >= 4 or connectionStoreEntry(staged, entry.id) <> invalid then return invalid
    staged.entries.push(entry)
    staged.selected = entry.id
    return staged
end function

function phoneSetupServerIdentity(url as string) as string
    base = normalizeBaseUrl(url)
    if base = "" then return ""
    parts = CreateObject("roRegex", "^(https?)://([^/]+)(.*)$", "i").match(base)
    if parts.count() <> 4 then return ""
    scheme = lcase(parts[1])
    authority = lcase(parts[2])
    if scheme = "https" and right(authority, 4) = ":443" then authority = left(authority, len(authority) - 4)
    if scheme = "http" and right(authority, 3) = ":80" then authority = left(authority, len(authority) - 3)
    return scheme + "://" + authority + parts[3]
end function

function phoneSetupDuplicateIds(store as object, candidate as object) as object
    result = []
    for each entry in store.entries
        if entry.provider = candidate.provider
            matches = false
            if candidate.provider = "m3u"
                digest = textValue(candidate.sourceDigest)
                if digest <> "" and textValue(entry.sourceDigest) = digest then matches = true
                if candidate.sessionUrl <> true and entry.sessionUrl <> true
                    url = phoneSetupServerIdentity(textValue(candidate.url))
                    if url <> "" and url = phoneSetupServerIdentity(textValue(entry.url)) then matches = true
                end if
            else
                url = phoneSetupServerIdentity(textValue(candidate.url))
                if url <> "" and url = phoneSetupServerIdentity(textValue(entry.url))
                    account = textValue(candidate.accountId)
                    savedAccount = textValue(entry.accountId)
                    if candidate.provider = "dispatcharr" and account <> "" and savedAccount <> ""
                        matches = account = savedAccount
                    else
                        username = textValue(candidate.accountUsername)
                        matches = username <> "" and username = textValue(entry.accountUsername)
                    end if
                end if
            end if
            if matches then result.push(entry.id)
        end if
    end for
    return result
end function
