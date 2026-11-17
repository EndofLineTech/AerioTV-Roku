' Device-local explicit offer choice. Payloads never write these settings.
function phoneSetupSyncOfferChoice(registry as object) as object
    settings = loadDispatcharrSyncSettings(registry)
    denied = {ok: false, enabled: false, declined: false}
    if not settings.ok then return denied
    declined = false
    count = 0
    for each key in settings.store.device
        if lcase(key) = "dispatcharrsyncofferdeclined"
            count++
            if not userProfileBoolean(settings.store.device[key]) then return denied
            declined = settings.store.device[key]
        end if
    end for
    if count > 1 then return denied
    return {ok: true, enabled: settings.enabled, declined: declined, store: settings.store}
end function

function phoneSetupDeclineSyncOffer(registry as object, capturedRoot as string) as object
    denied = {ok: false, recoveryRequired: false}
    if registry.read("settingsV1") <> capturedRoot then return denied
    choice = phoneSetupSyncOfferChoice(registry)
    if not choice.ok then return denied
    store = choice.store
    store.device = setCanonicalPreference(store.device, "dispatcharrSyncOfferDeclined", true)
    encoded = strictJsonEncode(store)
    if not encoded.ok then return denied
    if preferenceByteBudget(encoded.text) > 24000 then return denied
    changes = {}
    changes["settingsV1"] = encoded.text
    saved = userProfileRegistryTransaction(registry, changes)
    if saved.ok then saved.store = store
    return saved
end function
