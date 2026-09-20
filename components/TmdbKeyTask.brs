sub init()
    m.top.functionName = "testKey"
end sub

sub testKey()
    m.key = "" ' Never forward Dispatcharr credentials to TMDB.
    token = m.top.token.trim()
    encoder = CreateObject("roUrlTransfer")
    raw = requestJson("https://api.themoviedb.org/3/configuration?api_key=" + encoder.escape(token))
    ok = false
    if type(raw) = "roAssociativeArray" then ok = type(raw.images) = "roAssociativeArray"
    result = {ok: ok, message: m.failure}
    if ok then result.token = token
    m.top.token = ""
    if m.top.cancelRequested = true then return
    m.top.result = result
end sub
