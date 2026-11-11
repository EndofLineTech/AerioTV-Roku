' Bounded, local-only data for production guide and live overlay components.
function uiAuditChannels() as object
    rows = []
    for i = 1 to 24
        id = i.toStr()
        rows.push({id: id, uuid: "audit-" + id, name: "Synthetic Channel " + id, number: id, groupId: "news", tvgId: "audit-" + id, epgId: "", epgKey: "audit-" + id, logoId: "", logoUrl: ""})
    end for
    rows[1].name = "A deliberately long synthetic channel name"
    return rows
end function

function uiAuditGroups() as object
    return [{id: "news", name: "News"}, {id: "sports", name: "Sports"}, {id: "movies", name: "Movies"}, {id: "family", name: "Family & Children"}, {id: "long", name: "A deliberately long channel group name"}, {id: "local", name: "Local"}, {id: "international", name: "International"}]
end function

function uiAuditPrograms(channel as object, now as integer) as object
    rows = []
    startAt = (now \ 1800) * 1800
    for i = -4 to 8
        rows.push({id: "audit-program-" + channel.id + "-" + i.toStr(), key: channel.epgKey, title: "Synthetic Programme " + channel.number, subtitle: "A long episode title for testing populated layouts", description: "Original synthetic programme data. No provider or media request is connected."
            startsAt: startAt + i * 1800, endsAt: startAt + (i + 1) * 1800, season: "2", episode: "7", categories: [], poster: "", rating: "PG", year: "2026", quality: "HD", language: "English", country: "", credits: "", is_new: true, is_live: true, is_premiere: false, is_finale: false})
    end for
    return rows
end function
