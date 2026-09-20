function navigationMove(items as object, index as integer, delta as integer) as integer
    if delta <> -1 and delta <> 1 then return index
    target = index + delta
    while target >= 0 and target < items.count()
        if items[target].enabled = true then return target
        target += delta
    end while
    return index
end function

function navigationFirst(items as object, selected as string) as integer
    fallback = -1
    for i = 0 to items.count() - 1
        if items[i].enabled = true
            if fallback < 0 then fallback = i
            if items[i].id = selected then return i
        end if
    end for
    return fallback
end function
