' Read a bounded part of the same trusted live proxy URL while one Video plays.
' The transport stages in tmp, caps at 64 KiB, cancels after four seconds,
' and never exports response body, headers, URLs or credentials.
sub init()
    m.top.functionName = "probeHttp"
end sub

sub probeHttp()
    m.key = m.top.apiKey
    response = httpTransferOnce(m.top.url, invalid, "", 4000, 65536)
    m.key = ""
    m.top.apiKey = ""
    m.top.result = {status: response.status, bytes: response.bytes, error: response.error}
end sub
