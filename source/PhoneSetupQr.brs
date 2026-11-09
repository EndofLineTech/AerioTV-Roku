' Offline QR Model 2, fixed version 20, byte mode, ECC H, legal fixed mask 0.
' Capacity 382 ASCII bytes; setup links percent-encode every non-ASCII byte.
' ISO QR block parameters: 15*(43,15) + 10*(44,16), 28 parity bytes/block.
' Deliberately no logo overlay, network image service, or external dependency.
function phoneSetupQr(text as string) as dynamic
    if len(text) > 382 then return invalid
    bits = []
    phoneSetupQrBits(bits, 4, 4)
    phoneSetupQrBits(bits, len(text), 16)
    for i = 1 to len(text)
        value = asc(mid(text, i, 1))
        if value > 127 then return invalid
        phoneSetupQrBits(bits, value, 8)
    end for
    phoneSetupQrBits(bits, 0, 4)
    while bits.count() mod 8 <> 0
        bits.push(0)
    end while
    data = []
    for i = 0 to bits.count() - 1 step 8
        value = 0
        for j = 0 to 7
            value = value * 2 + bits[i + j]
        end for
        data.push(value)
    end for
    pad = 236
    while data.count() < 385
        data.push(pad)
        pad = 253 - pad
    end while
    gf = phoneSetupQrField()
    generator = [1]
    for degree = 0 to 27
        nextPoly = []
        for j = 0 to generator.count()
            nextPoly.push(0)
        end for
        for j = 0 to generator.count() - 1
            nextPoly[j] = phoneSetupQrXor(nextPoly[j], generator[j])
            nextPoly[j + 1] = phoneSetupQrXor(nextPoly[j + 1], phoneSetupQrMultiply(gf, generator[j], gf.exponents[degree]))
        end for
        generator = nextPoly
    end for
    blocks = []
    offset = 0
    for block = 0 to 24
        count = 15
        if block >= 15 then count = 16
        chunk = []
        parity = []
        for i = 0 to 27
            parity.push(0)
        end for
        for i = 0 to count - 1
            value = data[offset]
            offset++
            chunk.push(value)
            factor = phoneSetupQrXor(value, parity[0])
            for j = 0 to 27
                shifted = 0
                if j < 27 then shifted = parity[j + 1]
                parity[j] = phoneSetupQrXor(shifted, phoneSetupQrMultiply(gf, factor, generator[j + 1]))
            end for
        end for
        blocks.push({data: chunk, parity: parity})
    end for
    stream = []
    for i = 0 to 15
        for each block in blocks
            if i < block.data.count() then phoneSetupQrBits(stream, block.data[i], 8)
        end for
    end for
    for i = 0 to 27
        for each block in blocks
            phoneSetupQrBits(stream, block.parity[i], 8)
        end for
    end for
    matrix = []
    for y = 0 to 96
        row = []
        for x = 0 to 96
            row.push(-1)
        end for
        matrix.push(row)
    end for
    phoneSetupQrFinder(matrix, 3, 3)
    phoneSetupQrFinder(matrix, 93, 3)
    phoneSetupQrFinder(matrix, 3, 93)
    for each cy in [6, 34, 62, 90]
        for each cx in [6, 34, 62, 90]
            if matrix[cy][cx] = -1
                for dy = -2 to 2
                    for dx = -2 to 2
                        distance = abs(dx)
                        if abs(dy) > distance then distance = abs(dy)
                        value = 1
                        if distance = 1 then value = 0
                        matrix[cy + dy][cx + dx] = value
                    end for
                end for
            end if
        end for
    end for
    for i = 8 to 88
        if matrix[6][i] = -1 then matrix[6][i] = 1 - (i mod 2)
        if matrix[i][6] = -1 then matrix[i][6] = 1 - (i mod 2)
    end for
    ' Format H (2), mask 0; BCH(15,5), then the required 0x5412 XOR.
    remainder = 16 * 1024
    for bit = 14 to 10 step -1
        if phoneSetupQrBit(remainder, bit) = 1 then remainder = phoneSetupQrXor(remainder, 1335 * int(2 ^ (bit - 10)))
    end for
    format = phoneSetupQrXor(16 * 1024 + remainder, 21522)
    for i = 0 to 14
        value = phoneSetupQrBit(format, i)
        y = 97 - 15 + i
        if i < 6 then y = i
        if i >= 6 and i < 8 then y = i + 1
        matrix[y][8] = value
        x = 15 - i - 1
        if i < 8 then x = 97 - i - 1
        if i = 8 then x = 15 - i
        matrix[8][x] = value
    end for
    matrix[89][8] = 1
    remainder = 20 * 4096
    for bit = 17 to 12 step -1
        if phoneSetupQrBit(remainder, bit) = 1 then remainder = phoneSetupQrXor(remainder, 7973 * int(2 ^ (bit - 12)))
    end for
    version = 20 * 4096 + remainder
    for i = 0 to 17
        x = 86 + (i mod 3)
        y = int(i / 3)
        matrix[y][x] = phoneSetupQrBit(version, i)
        matrix[x][y] = phoneSetupQrBit(version, i)
    end for
    index = 0
    rightColumn = 96
    upward = true
    while rightColumn >= 1
        if rightColumn = 6 then rightColumn = 5
        for stepIndex = 0 to 96
            y = stepIndex
            if upward then y = 96 - stepIndex
            for x = rightColumn to rightColumn - 1 step -1
                if matrix[y][x] = -1
                    value = 0
                    if index < stream.count() then value = stream[index]
                    index++
                    if (x + y) mod 2 = 0 then value = 1 - value
                    matrix[y][x] = value
                end if
            end for
        end for
        upward = not upward
        rightColumn -= 2
    end while
    rows = []
    for each row in matrix
        text = ""
        for each value in row
            text += value.toStr()
        end for
        rows.push(text)
    end for
    return rows
end function

sub phoneSetupQrFinder(matrix as object, cx as integer, cy as integer)
    for dy = -4 to 4
        for dx = -4 to 4
            x = cx + dx
            y = cy + dy
            if x >= 0 and x < 97 and y >= 0 and y < 97
                distance = abs(dx)
                if abs(dy) > distance then distance = abs(dy)
                value = 1
                if distance = 2 or distance = 4 then value = 0
                matrix[y][x] = value
            end if
        end for
    end for
end sub

sub phoneSetupQrBits(bits as object, value as integer, count as integer)
    for bit = count - 1 to 0 step -1
        bits.push(phoneSetupQrBit(value, bit))
    end for
end sub

function phoneSetupQrBit(value as integer, bit as integer) as integer
    return int(value / (2 ^ bit)) mod 2
end function

function phoneSetupQrXor(a as integer, b as integer) as integer
    return (a or b) - (a and b)
end function

function phoneSetupQrField() as object
    exponents = []
    logarithms = []
    for i = 0 to 255
        logarithms.push(0)
    end for
    value = 1
    for i = 0 to 254
        exponents.push(value)
        logarithms[value] = i
        value *= 2
        if value >= 256 then value = phoneSetupQrXor(value, 285)
    end for
    return {exponents: exponents, logarithms: logarithms}
end function

function phoneSetupQrMultiply(gf as object, a as integer, b as integer) as integer
    if a = 0 or b = 0 then return 0
    return gf.exponents[(gf.logarithms[a] + gf.logarithms[b]) mod 255]
end function
