' FormatJson emits integral floating values as integer literals on native Roku.
' Preserve their JSON number kind explicitly; the checked result is then passed
' unchanged to HttpTransport. Parsing untrusted input still needs ParseJson("d")
' and schema/case/size validation by the caller before this serializer is used.
function strictJsonEncode(value as dynamic, depth = 0 as integer) as object
    if depth > 32 then return {ok: false, text: ""}
    kind = type(value)
    if value = invalid then return {ok: true, text: "null"}
    if kind = "roArray" or kind = "roAssociativeArray"
        parts = []
        for each item in value
            member = item
            if kind = "roAssociativeArray" then member = value[item]
            encoded = strictJsonEncode(member, depth + 1)
            if not encoded.ok then return encoded
            text = encoded.text
            if kind = "roAssociativeArray" then text = FormatJson(item, 1) + ":" + text
            parts.push(text)
        end for
        text = ""
        for each part in parts
            if text <> "" then text += ","
            text += part
        end for
        if kind = "roArray" then return {ok: true, text: "[" + text + "]"}
        return {ok: true, text: "{" + text + "}"}
    end if
    if kind = "String" or kind = "roString" or kind = "Boolean" or kind = "roBoolean"
        return {ok: true, text: FormatJson(value, 1)}
    end if
    integral = kind = "Integer" or kind = "roInt" or kind = "roInteger" or kind = "LongInteger" or kind = "roLongInteger"
    floating = kind = "Float" or kind = "roFloat" or kind = "Double" or kind = "roDouble"
    if not integral and not floating then return {ok: false, text: ""}
    text = FormatJson(value, 1)
    ' Native FormatJson can shorten a Double enough to change its value for
    ' another reader. Seventeen significant digits round-trip IEEE binary64.
    if kind = "Double" or kind = "roDouble" then text = value.toStr("%.17g")
    if not CreateObject("roRegex", "^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$", "").isMatch(text) then return {ok: false, text: ""}
    if floating and instr(1, text, ".") = 0 and instr(1, lcase(text), "e") = 0 then text += ".0"
    return {ok: true, text: text}
end function
