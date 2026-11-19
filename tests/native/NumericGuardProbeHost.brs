sub Main()
    runNumericGuardProbe(false)
end sub

function numericValidatePhonePayload(raw as dynamic) as object
    return validatePhoneSetupPayload(raw)
end function
