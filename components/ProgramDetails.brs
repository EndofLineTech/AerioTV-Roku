sub init()
    m.top.visible = false
    m.index = 0
    uiRect(m.top, 0, 0, 1920, 1080, "0x0A1628FF")
    m.title = uiLabel(m.top, "", 96, 80, 1220, 120, 36)
    m.title.wrap = true
    m.when = uiLabel(m.top, "", 96, 215, 1220, 72, 24, "0x1AC4D8FF")
    m.when.wrap = true
    m.poster = m.top.createChild("Poster")
    m.poster.translation = [96, 320]
    m.poster.width = 310
    m.poster.height = 465
    m.poster.loadWidth = 620
    m.poster.loadHeight = 930
    m.poster.loadDisplayMode = "scaleToFit"
    m.tmdbLogo = m.top.createChild("Poster")
    m.tmdbLogo.translation = [96, 825]
    m.tmdbLogo.width = 250
    m.tmdbLogo.height = 32
    m.tmdbLogo.uri = "pkg:/images/tmdb-logo.png"
    m.tmdbLogo.loadDisplayMode = "scaleToFit"
    m.tmdbLogo.visible = false
    m.facts = uiLabel(m.top, "", 460, 320, 1320, 75, 23, "0x1AC4D8FF")
    m.facts.wrap = true
    m.description = uiLabel(m.top, "", 460, 405, 1320, 240, 24)
    m.description.wrap = true
    m.description.maxLines = 8
    m.credits = uiLabel(m.top, "", 460, 660, 1320, 62, 22, "0x9EB5C9FF")
    m.credits.wrap = true
    m.buttons = []
    for i = 0 to 2
        bg = uiRect(m.top, 460, 750 + i * 74, 1320, 64, "0x17344AFF")
        label = uiLabel(m.top, "", 480, 768 + i * 74, 1280, 40, 25)
        m.buttons.push({bg: bg, label: label})
    end for
    m.attribution = uiLabel(m.top, "", 96, 1005, 1728, 38, 20, "0x9EB5C9FF")
end sub

sub onActive()
    m.top.visible = m.top.active
    if m.top.active
        m.index = 0
        m.top.setFocus(true)
        render()
    end if
end sub

sub render()
    model = m.top.model
    if model = invalid then return
    p = model.program
    m.attribution.text = "Guide-provider metadata. Back returns to the same guide position."
    m.tmdbLogo.visible = p.artSource = "TMDB"
    if p.artSource = "TMDB" then m.attribution.text = "Uses the TMDB API but is not endorsed or certified by TMDB. https://www.themoviedb.org"
    m.title.text = p.title
    m.when.text = model.channel.name + "  |  " + uiLocalDate(p.startsAt) + " " + uiTime(p.startsAt) + " - " + uiTime(p.endsAt)
    m.facts.text = programBadges(p, model.settings) + "  " + textValue(p.rating) + "  " + textValue(p.year) + "  " + textValue(p.quality)
    m.facts.text += "  " + textValue(p.language) + "  " + textValue(p.country)
    if textValue(model.catchupRetention) <> "" then m.facts.text += "  |  " + model.catchupRetention + " (provider advertised)"
    categories = ""
    for i = 0 to p.categories.count() - 1
        if i >= 3 then exit for
        if categories <> "" then categories += " / "
        categories += left(p.categories[i], 40)
    end for
    if categories <> "" then m.facts.text += chr(10) + categories
    m.description.text = p.subtitle + chr(10) + p.description
    m.credits.text = textValue(p.credits)
    if textValue(model.message) <> "" then m.credits.text = model.message
    uri = textValue(p.poster)
    same = trustedPageUrl(model.baseUrl, uri)
    scope = "public"
    if same <> ""
        uri = same
        scope = model.baseUrl + "|" + model.apiKey
    else if left(uri, 8) <> "https://" or instr(1, uri, "@") > 0
        uri = ""
    end if
    if uri <> m.poster.uri or scope <> m.posterScope
        m.poster.uri = ""
        agent = CreateObject("roHttpAgent")
        agent.setCertificatesFile("common:/certs/ca-bundle.crt")
        if same <> ""
            agent.setHeaders({"X-API-Key": model.apiKey, "Authorization": "ApiKey " + model.apiKey})
        end if
        m.poster.setHttpAgent(agent)
        m.posterScope = scope
        m.poster.uri = uri
    end if
    m.actions = ["watch", "close"]
    labels = ["Watch channel LIVE", "Close"]
    if p.startsAt > uiNow() or model.reminded
        m.actions = ["watch", "reminder", "close"]
        label = "Remind me (foreground, 5 minutes before)"
        if model.reminded then label = "Cancel reminder"
        labels = ["Watch channel LIVE", label, "Close"]
    end if
    if model.catchupAvailable = true
        m.actions = ["catchup", "watch", "close"]
        labels = ["Play archive (provider availability)", "Watch channel LIVE", "Close"]
    end if
    if m.index >= labels.count() then m.index = labels.count() - 1
    for i = 0 to 2
        row = m.buttons[i]
        row.bg.visible = i < labels.count()
        row.label.visible = row.bg.visible
        if row.bg.visible
            row.label.text = labels[i]
            row.bg.color = "0x17344AFF"
            row.label.color = "0xE8F3FAFF"
            if i = m.index
                row.bg.color = "0x1AC4D8FF"
                row.label.color = "0x0A1628FF"
            end if
        end if
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if key = "back"
        m.top.action = "close"
    else if key = "OK"
        m.top.action = m.actions[m.index]
    else if key = "up"
        if m.index > 0 then m.index--
        render()
    else if key = "down"
        if m.index < m.actions.count() - 1 then m.index++
        render()
    end if
    return true
end function
