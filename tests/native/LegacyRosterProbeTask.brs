sub init()
    m.top.functionName = "probeLegacyRoster"
end sub

sub probeLegacyRoster()
    m.registry = CreateObject("roRegistrySection", "AerioTVMigrationProbeV1")
    for each key in ["connectionsV1", "serverUrl", "accountIdentity", "apiKey", "connKey_legacy", "rememberApiKey"]
        m.registry.delete(key)
    end for
    m.registry.flush()
    ready = m.registry.write("serverUrl", "https://example.test")
    ready = m.registry.write("accountIdentity", "https://example.test|7") and ready
    ready = m.registry.write("apiKey", "fixture-only") and ready
    ready = m.registry.write("rememberApiKey", "true") and ready
    ready = m.registry.flush() and ready
    if ready
        m.connectionStore = loadConnectionStore(m.registry)
        m.selectedConnectionId = "legacy"
        m.baseUrl = "https://example.test"
        m.apiKey = "fixture-only"
        m.remember = true
        ready = rememberConnectedAccount("7")
    end if
    if ready
        ready = m.registry.read("serverUrl") = "https://example.test"
        ready = m.registry.read("connKey_legacy") = "fixture-only" and ready
        m.registry.delete("connectionsV1")
        m.registry.flush()
    end if
    if ready
        recovered = loadConnectionStore(m.registry)
        ready = recovered.selected = "legacy" and recovered.entries.count() = 1
        if ready then ready = storedConnectionKey(m.registry, recovered.entries[0]) = "fixture-only"
    end if
    if ready
        ' Non-empty truncated metadata is not a fresh install. Preserve the
        ' legacy key and corrupt bytes for operator recovery; never replace it.
        corrupt = "{truncated"
        ready = m.registry.write("connectionsV1", corrupt) and m.registry.flush()
        if ready
            damaged = loadConnectionStore(m.registry)
            ready = damaged.readOnly = true and not connectionWelcomeNeeded(damaged)
            ready = not saveConnectionStore(m.registry, damaged) and ready
            ready = m.registry.read("connectionsV1") = corrupt and ready
            ready = m.registry.read("connKey_legacy") = "fixture-only" and ready
        end if
    end if
    for each key in ["connectionsV1", "serverUrl", "accountIdentity", "apiKey", "connKey_legacy", "rememberApiKey"]
        m.registry.delete(key)
    end for
    m.registry.flush()
    m.top.result = {ok: ready}
end sub
