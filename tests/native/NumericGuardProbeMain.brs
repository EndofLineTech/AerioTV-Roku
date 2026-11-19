sub Main()
    runNumericGuardProbe(true)
end sub

function numericValidatePhonePayload(raw as dynamic) as object
    ' Keep reporting other rows if a native numeric type throws inside Fix().
    try
        return validatePhoneSetupPayload(raw)
    catch error
        return {probeException: true}
    end try
end function
