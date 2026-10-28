' Synthetic-only results. Update output is never considered authenticated.
sub phoneProbeMatrix()
    rows = parseJson(ReadAsciiFile("pkg:/fixtures.json"))
    for each row in rows
        for each mode in ["process", "stream", "settag-stream"]
            cipher = CreateObject("roEVPCipher")
            status = cipher.setup(false, "aes-256-gcm", row.key, row.nonce, 0)
            result = {id: row.id, mode: mode, valid: row.valid, setup: status, accepted: false, updateBytes: 0, updatePlainMatches: false, finalValid: false}
            if status = 0
                if mode = "process"
                    output = cipher.process(phoneProbeBytes(row.ciphertext + row.tag))
                    result.finalValid = type(output) = "roByteArray"
                    if result.finalValid then result.accepted = lcase(output.toHexString()) = row.plain
                else if mode = "settag-stream"
                    ' Wire contract rejects missing/truncated tags before native crypto.
                    if len(row.tag) = 32
                        cipher.setTag(phoneProbeBytes(row.tag))
                        combined = ""
                        output = cipher.update(phoneProbeBytes(row.ciphertext))
                        if type(output) = "roByteArray" then combined = output.toHexString()
                        tail = cipher.final()
                        result.finalValid = type(tail) = "roByteArray"
                        if result.finalValid then result.accepted = lcase(combined + tail.toHexString()) = row.plain
                    else
                        result.tagLengthRejected = true
                    end if
                else
                    output = cipher.update(phoneProbeBytes(row.ciphertext))
                    combined = ""
                    if type(output) = "roByteArray"
                        result.updateBytes = output.count()
                        combined = output.toHexString()
                        result.updatePlainMatches = lcase(combined) = row.plain
                    end if
                    tagOutput = cipher.update(phoneProbeBytes(row.tag))
                    if type(tagOutput) = "roByteArray" then combined += tagOutput.toHexString()
                    tail = cipher.final()
                    result.finalValid = type(tail) = "roByteArray"
                    if result.finalValid then result.accepted = lcase(combined + tail.toHexString()) = row.plain
                end if
            end if
            print "[setup-matrix] "; formatJson(result)
        end for
        if row.valid
            cipher = CreateObject("roEVPCipher")
            status = cipher.setup(true, "aes-256-gcm", row.key, row.nonce, 0)
            output = cipher.process(phoneProbeBytes(row.plain))
            matches = false
            tagged = false
            actual = "invalid"
            if type(output) = "roByteArray"
                actual = lcase(output.toHexString())
                matches = lcase(output.toHexString()) = row.ciphertext
                tagged = lcase(output.toHexString()) = row.ciphertext + row.tag
            end if
            tag = cipher.getTag()
            tagMatches = false
            if type(tag) = "roByteArray" then tagMatches = lcase(tag.toHexString()) = row.tag
            print "[setup-matrix] "; formatJson({id: row.id, mode: "encrypt", setup: status, ciphertextMatches: matches, taggedMatches: tagged, tagMatches: tagMatches, actual: actual})
        end if
    end for
    print "[setup-matrix] complete-v1"
end sub
