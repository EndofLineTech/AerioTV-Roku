' Video.seek uses seconds from the beginning of the current reader. A growing
' HLS manifest can advance while a remote key is held; leave a small edge
' margin and never send a guessed/unbounded request to the native player.
function recordingSeekTarget(position as dynamic, duration as dynamic, direction as integer, stepSeconds as integer, growing as boolean) as dynamic
    if not mediaNumber(position) or not mediaNumber(duration) then return invalid
    if position < 0 or duration < 12 or duration > 864000 then return invalid
    if direction <> -1 and direction <> 1 then return invalid
    if stepSeconds < 1 or stepSeconds > 300 then return invalid
    last = int(duration) - 1
    if growing then last = int(duration) - 6
    if last < 0 then return invalid
    start = int(position)
    if start > last then start = last
    target = start + direction * stepSeconds
    if target < 0 then target = 0
    if target > last then target = last
    return {position: target, last: last, moved: target <> start}
end function
