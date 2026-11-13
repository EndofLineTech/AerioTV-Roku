' Render-thread checks never wait for a Task. Every native renderer is tagged
' with digest-only context so a later broker transition can clear/stop it.
function requestGateRenderContextAllowed(server as string, hash as string) as boolean
    broker = requestGateBroker()
    if broker = invalid then return not requestGateMandatory()
    if not broker.ready then return false
    state = broker.snapshot
    if type(state) <> "roAssociativeArray" then return false
    permit = requestGatePermit(state, server, hash, CreateObject("roDateTime").asSeconds(), false)
    return permit.allowed
end function

function requestGateRenderAllowed(uri as string, key as string) as boolean
    if uri = "" or left(uri, 5) = "pkg:/" or left(uri, 5) = "tmp:/" then return true
    if requestGateBroker() = invalid and not requestGateMandatory() then return true
    hash = requestGateCredentialHash(key)
    if key <> "" and hash = "" then return false
    return requestGateRenderContextAllowed(requestGateServer(uri), hash)
end function

function requestGateTrackRenderer(node as object, uri as string, key as string) as boolean
    if requestGateBroker() = invalid and not requestGateMandatory() then return true
    if not node.hasField("gatehost") then node.addFields({gatehost: "", gatehash: ""})
    node.gatehost = ""
    node.gatehash = ""
    if uri = "" or left(uri, 5) = "pkg:/" or left(uri, 5) = "tmp:/" then return true
    node.gatehost = requestGateServer(uri)
    node.gatehash = requestGateCredentialHash(key)
    return requestGateRenderAllowed(uri, key)
end function

sub requestGateSetPoster(node as object, uri as string, key as string)
    if not requestGateTrackRenderer(node, uri, key) then uri = ""
    if node.uri <> uri then node.uri = uri
end sub

function requestGateRendererAllowed(node as object) as boolean
    if node = invalid then return true
    if type(node) <> "roSGNode" then return true
    if not node.hasField("gatehost") then return true
    if node.gatehost = "" then return true
    return requestGateRenderContextAllowed(node.gatehost, node.gatehash)
end function

sub requestGateFenceRenderers(root as object)
    if not requestGateRendererAllowed(root)
        if root.isSubtype("Poster") then root.uri = ""
        if root.isSubtype("Video")
            root.control = "stop"
            root.content = invalid
        end if
        for each field in ["hdGridPosterUrl", "sdGridPosterUrl", "hdPosterUrl", "sdPosterUrl"]
            if root.hasField(field) then root[field] = ""
        end for
    end if
    if root.hasField("content")
        if type(root.content) = "roSGNode" then requestGateFenceRenderers(root.content)
    end if
    for each child in root.getChildren(-1, 0)
        requestGateFenceRenderers(child)
    end for
end sub
