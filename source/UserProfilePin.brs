' v2 import/verification only. There is deliberately no salt-creation API.
function userProfilePinCreationAllowed() as boolean
    return false
end function

function userProfilePinGrantMatches(grant as dynamic, slotId as string, profile as object) as boolean
    if type(grant) <> "roAssociativeArray" then return false
    if not userProfilePinRecordValid(profile) then return false
    for each field in ["slot", "id", "pinType", "pinHash", "pinSalt"]
        if type(grant[field]) <> "String" and type(grant[field]) <> "roString" then return false
    end for
    return grant.slot = slotId and grant.id = profile.id and grant.pinType = profile.pinType and grant.pinHash = profile.pinHash and grant.pinSalt = profile.pinSalt
end function

function userProfilePinNormalize(pinType as string, entries as dynamic) as dynamic
    if type(entries) <> "roArray" then return invalid
    if entries.count() < 4 or entries.count() > 6 then return invalid
    if pinType <> "numbers" and pinType <> "directions" then return invalid
    normalized = ""
    directions = {up: "U", u: "U", down: "D", d: "D", left: "L", l: "L", right: "R", r: "R"}
    for each entry in entries
        if type(entry) <> "String" and type(entry) <> "roString" then return invalid
        if pinType = "numbers"
            if not CreateObject("roRegex", "^[0-9]$", "").isMatch(entry) then return invalid
            normalized += entry
        else
            key = lcase(entry)
            if not directions.doesExist(key) then return invalid
            normalized += directions[key]
        end if
    end for
    return normalized
end function

function userProfilePinRecordValid(record as dynamic) as boolean
    if type(record) <> "roAssociativeArray" then return false
    if record.pinType <> "numbers" and record.pinType <> "directions" then return false
    if type(record.pinHash) <> "String" and type(record.pinHash) <> "roString" then return false
    if type(record.pinSalt) <> "String" and type(record.pinSalt) <> "roString" then return false
    return CreateObject("roRegex", "^[0-9a-fA-F]{64}$", "").isMatch(record.pinHash) and CreateObject("roRegex", "^[0-9a-fA-F]{32}$", "").isMatch(record.pinSalt)
end function

' Fixed work for well-formed hashes: compare all 64 characters, never exit on
' a mismatched character. BrightScript cannot promise machine-level constant
' time; this avoids an application-level prefix timing oracle.
function userProfilePinDigestMatches(actual as string, expected as string) as boolean
    hex = CreateObject("roRegex", "^[0-9a-fA-F]{64}$", "")
    if not hex.isMatch(actual) or not hex.isMatch(expected) then return false
    actual = lcase(actual)
    expected = lcase(expected)
    difference = 0
    for i = 1 to 64
        difference += abs(asc(mid(actual, i, 1)) - asc(mid(expected, i, 1)))
    end for
    return difference = 0
end function

' Native-only crypto boundary. Host suites test pure rules, while the isolated
' device probe runs all four shared vectors with the real digest implementation.
function userProfilePinHash(saltHex as string, normalized as string) as dynamic
    if not CreateObject("roRegex", "^[0-9a-fA-F]{32}$", "").isMatch(saltHex) then return invalid
    if not CreateObject("roRegex", "^([0-9]{4,6}|[UDLR]{4,6})$", "").isMatch(normalized) then return invalid
    salt = CreateObject("roByteArray")
    salt.fromHexString(saltHex)
    input = CreateObject("roByteArray")
    input.fromAsciiString(normalized)
    digest = CreateObject("roEVPDigest")
    if digest = invalid then return invalid
    if digest.setup("sha256") <> 0 then return invalid
    digest.update(salt)
    digest.update(input)
    return lcase(digest.final())
end function
