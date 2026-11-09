' ISOLATED PROBE ONLY. Known public RFC fixtures; never accepts real secrets.
' The normal package uses source/PhoneSetupEntropy.brs, which fails closed.
function phoneSetupNewMaterial(cancelled = invalid as dynamic) as dynamic
    if m.fixtureIndex = invalid then m.fixtureIndex = 0
    rows = parseJson(ReadAsciiFile("pkg:/fixture-materials.json"))
    index = m.fixtureIndex
    if index > 1 then index = 1
    row = rows[index]
    m.fixtureIndex++
    public = setupX25519(setupX25519HexBytes(row.privateHex), setupX25519HexBytes("09" + string(62, "0")), cancelled)
    if public = invalid then return invalid
    if setupX25519Hex(public) <> row.publicHex then return invalid
    return row
end function
