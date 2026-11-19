function guideAllAvailableDays() as integer
    return 30
end function

function guideDayChoices() as object
    choices = []
    for days = 1 to 14
        choices.push(days)
    end for
    choices.push(guideAllAvailableDays())
    return choices
end function
