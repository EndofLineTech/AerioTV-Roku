' Experimental RFC 7748 section 5 Montgomery ladder. Probe/test package ONLY.
' Field limbs are base 2^15 (17 limbs); 2^255 = 19 modulo p.
' Double accumulators are exact: the largest convolution sum is below 2^40,
' well inside IEEE-754's 53-bit integer precision. Never use Float arithmetic.
' This is NOT a CSPRNG, production crypto approval, or a constant-time guarantee
' for the Roku interpreter. Inputs/outputs are 32-byte numeric arrays.
function setupX25519(secret as object, peer as object) as object
    scalar = []
    for each value in secret
        scalar.push(value)
    end for
    scalar[0] = int(scalar[0] / 8) * 8
    scalar[31] = 64 + (scalar[31] mod 64)
    x1 = setupX25519Unpack(peer)
    x2 = setupX25519Field(1)
    z2 = setupX25519Field(0)
    x3 = setupX25519Field(0)
    for i = 0 to 16
        x3[i] = x1[i]
    end for
    z3 = setupX25519Field(1)
    swap = 0
    powers = [1, 2, 4, 8, 16, 32, 64, 128]
    for bit = 254 to 0 step -1
        digit = int(scalar[int(bit / 8)] / powers[bit mod 8]) mod 2
        setupX25519Swap(x2, x3, (swap + digit) mod 2)
        setupX25519Swap(z2, z3, (swap + digit) mod 2)
        swap = digit
        a = setupX25519Add(x2, z2)
        aa = setupX25519Mul(a, a)
        b = setupX25519Sub(x2, z2)
        bb = setupX25519Mul(b, b)
        e = setupX25519Sub(aa, bb)
        c = setupX25519Add(x3, z3)
        d = setupX25519Sub(x3, z3)
        da = setupX25519Mul(d, a)
        cb = setupX25519Mul(c, b)
        sum = setupX25519Add(da, cb)
        difference = setupX25519Sub(da, cb)
        x3 = setupX25519Mul(sum, sum)
        z3 = setupX25519Mul(x1, setupX25519Mul(difference, difference))
        x2 = setupX25519Mul(aa, bb)
        z2 = setupX25519Mul(e, setupX25519Add(aa, setupX25519Scale(e, 121665)))
    end for
    setupX25519Swap(x2, x3, swap)
    setupX25519Swap(z2, z3, swap)
    inverse = setupX25519Field(1)
    ' p-2 = 2^255-21: every bit set except bit 4 and bit 2.
    for bit = 254 to 0 step -1
        inverse = setupX25519Mul(inverse, inverse)
        if bit <> 4 and bit <> 2 then inverse = setupX25519Mul(inverse, z2)
    end for
    return setupX25519Pack(setupX25519Mul(x2, inverse))
end function

function setupX25519Field(first as integer) as object
    result = []
    for i = 0 to 16
        result.push(0.0#)
    end for
    result[0] = first * 1.0#
    return result
end function

sub setupX25519Swap(a as object, b as object, swap as integer)
    for i = 0 to 16
        difference = (a[i] - b[i]) * swap
        a[i] = a[i] - difference
        b[i] = b[i] + difference
    end for
end sub

function setupX25519Carry(value as object) as object
    for pass = 0 to 2
        for i = 0 to 16
            ' Roku integer division narrows its operands to Int32. Int(Double)
            ' instead narrows through Float and can round UP near a boundary.
            ' The quotient is <2^24, so correct that possible +1 in Double.
            carry = int(value[i] / 32768.0#)
            if carry * 32768.0# > value[i] then carry = carry - 1
            value[i] = value[i] - carry * 32768.0#
            if i < 16
                value[i + 1] = value[i + 1] + carry
            else
                value[0] = value[0] + carry * 19.0#
            end if
        end for
    end for
    return value
end function

function setupX25519Add(a as object, b as object) as object
    result = []
    for i = 0 to 16
        result.push(a[i] + b[i])
    end for
    return setupX25519Carry(result)
end function

function setupX25519Sub(a as object, b as object) as object
    result = []
    for i = 0 to 16
        result.push(a[i] - b[i] + 65534.0#)
    end for
    result[0] = result[0] - 36.0#
    return setupX25519Carry(result)
end function

function setupX25519Scale(a as object, scalar as integer) as object
    result = []
    for i = 0 to 16
        result.push(a[i] * (scalar * 1.0#))
    end for
    return setupX25519Carry(result)
end function

function setupX25519Mul(a as object, b as object) as object
    result = []
    for i = 0 to 32
        result.push(0.0#)
    end for
    for i = 0 to 16
        for j = 0 to 16
            result[i + j] = result[i + j] + a[i] * b[j]
        end for
    end for
    for i = 32 to 17 step -1
        result[i - 17] = result[i - 17] + 19.0# * result[i]
    end for
    ' Carries are at most ~10 million for the bounded convolution above.
    return setupX25519Carry(result)
end function

function setupX25519Unpack(bytes as object) as object
    result = []
    accumulator = 0.0#
    bits = 0
    for i = 0 to 31
        value = bytes[i]
        if i = 31 then value = value mod 128
        accumulator = accumulator + value * (2.0# ^ bits)
        bits = bits + 8
        if bits >= 15
            carry = accumulator \ 32768.0#
            result.push(accumulator - carry * 32768.0#)
            accumulator = carry * 1.0#
            bits = bits - 15
        end if
    end for
    return result
end function

function setupX25519Pack(value as object) as object
    reduced = []
    borrow = 0
    for i = 0 to 16
        limb = value[i] - 32767.0# - borrow
        if i = 0 then limb = limb + 18.0#
        borrow = 1 - ((limb + 32768.0#) \ 32768.0#)
        reduced.push(limb + borrow * 32768.0#)
    end for
    for i = 0 to 16
        value[i] = value[i] * borrow + reduced[i] * (1 - borrow)
    end for
    result = []
    accumulator = 0.0#
    bits = 0
    for i = 0 to 16
        accumulator = accumulator + value[i] * (2.0# ^ bits)
        bits = bits + 15
        while bits >= 8
            carry = accumulator \ 256.0#
            result.push((accumulator - carry * 256.0#) \ 1)
            accumulator = carry * 1.0#
            bits = bits - 8
        end while
    end for
    result.push(accumulator \ 1)
    return result
end function

' Synthetic probe/test convenience only, not an external-input decoder.
function setupX25519HexBytes(value as string) as object
    result = []
    alphabet = "0123456789abcdef"
    for i = 1 to len(value) step 2
        result.push((instr(1, alphabet, mid(value, i, 1)) - 1) * 16 + instr(1, alphabet, mid(value, i + 1, 1)) - 1)
    end for
    return result
end function

function setupX25519Hex(bytes as object) as string
    result = ""
    alphabet = "0123456789abcdef"
    for each value in bytes
        result += mid(alphabet, int(value / 16) + 1, 1) + mid(alphabet, value mod 16 + 1, 1)
    end for
    return result
end function
