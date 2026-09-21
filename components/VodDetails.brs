sub init()
    m.actions = m.top.findNode("actions")
    font = m.actions.font
    font.size = 24
    m.actions.font = font
    focusedFont = m.actions.focusedFont
    focusedFont.size = 26
    m.actions.focusedFont = focusedFont
    messageFont = m.top.findNode("message").font
    messageFont.size = 24
    m.top.findNode("message").font = messageFont
    m.poster = m.top.findNode("poster")
    m.placeholder = m.top.findNode("placeholder")
    m.actions.observeField("itemSelected", "onAction")
    m.poster.observeField("loadStatus", "onPosterStatus")
    m.loadedUri = ""
    renderAttribution()
end sub

sub renderText()
    m.top.findNode("title").text = m.top.title
    m.top.findNode("message").text = m.top.message
end sub

sub renderButtons()
    focused = m.actions.itemFocused
    content = CreateObject("roSGNode", "ContentNode")
    for each label in m.top.buttons
        content.createChild("ContentNode").title = label
    end for
    m.actions.content = content
    if focused >= 0 and focused < m.top.buttons.count() then m.actions.jumpToItem = focused
end sub

sub focusActions()
    m.actions.setFocus(true)
end sub

sub loadPoster()
    uri = m.top.posterUri
    if uri = "" then uri = m.top.fallbackUri
    if m.loadedUri = uri and uri <> ""
        if m.poster.loadStatus = "failed" then onPosterStatus()
        return
    end if
    setPosterUri(uri)
end sub

sub setPosterUri(uri as string)
    protected = trustedPageUrl(m.top.baseUrl, uri) <> ""
    if not protected and not CreateObject("roRegex", "^https://image\.tmdb\.org/t/p/w[0-9]+/[A-Za-z0-9_-]+\.(jpg|png)$", "i").isMatch(uri) then uri = ""
    agent = CreateObject("roHttpAgent")
    agent.setCertificatesFile("common:/certs/ca-bundle.crt")
    if protected then agent.setHeaders({"X-API-Key": m.top.apiKey})
    m.poster.setHttpAgent(agent)
    m.loadedUri = uri
    m.poster.uri = uri
    m.placeholder.visible = uri = ""
end sub

sub onPosterStatus()
    if m.poster.loadStatus = "ready" then m.placeholder.visible = false
    if m.poster.loadStatus = "failed"
        fallback = m.top.fallbackUri
        if fallback <> "" and fallback <> m.loadedUri then setPosterUri(fallback) else m.placeholder.visible = true
    end if
end sub

sub renderAttribution()
    m.top.findNode("tmdbLogo").visible = m.top.tmdbUsed
    text = "Provider metadata. Availability depends on this account's catalog."
    if m.top.tmdbUsed then text = "Includes TMDB metadata (English requested). This product uses the TMDB API but is not endorsed or certified by TMDB."
    m.top.findNode("attribution").text = text
end sub

sub onAction(event as object)
    if m.top.close then return
    m.top.buttonSelected = event.getData()
end sub

sub closeDetails()
    if not m.top.close then return
    m.top.visible = false
    m.poster.uri = ""
    m.top.apiKey = ""
    m.top.wasClosed = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back"
        m.top.close = true
        return true
    end if
    return false
end function
