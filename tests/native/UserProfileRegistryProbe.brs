' Disposable capacity measurement. Never enumerate/read application sections.
' UUID namespacing prevents deleting any existing section; UUID is NOT entropy
' for a PIN salt, pairing key or other security function.
sub profileProbeRegistry()
    registry = CreateObject("roRegistry")
    sectionName = "AerioProfileProbe-" + CreateObject("roDeviceInfo").getRandomUUID()
    baseline = registry.getSpaceAvailable()
    fixtures = ParseJson(ReadAsciiFile("pkg:/profile-registry-fixtures.json"))
    print "[profile-probe] registry-baseline="; baseline
    for each fixture in fixtures
        section = CreateObject("roRegistrySection", sectionName)
        written = true
        for each key in fixture.values
            written = section.write(key, fixture.values[key]) and written
        end for
        flushed = section.flush()
        available = registry.getSpaceAvailable()
        verified = written and flushed
        if verified
            for each key in fixture.values
                if section.read(key) <> fixture.values[key] then verified = false
            end for
        end if
        print "[profile-probe] registry profiles-per-slot="; fixture.profilesPerSlot; " four-slots=true full-preferences=24000 saved="; verified; " available="; available
        ' Delete only this newly allocated probe section, even on write failure.
        section = invalid
        removed = registry.delete(sectionName)
        removed = registry.flush() and removed
        ' GetSpaceAvailable may change after registry recompression; prove
        ' cleanup by reading ONLY our disposable section's key list instead
        ' of assuming byte-for-byte accounting is stable across a flush.
        checkSection = CreateObject("roRegistrySection", sectionName)
        empty = checkSection.getKeyList().count() = 0
        checkSection = invalid
        removed = registry.delete(sectionName) and removed
        removed = registry.flush() and removed
        print "[profile-probe] registry-cleanup removed="; removed; " empty="; empty; " available="; registry.getSpaceAvailable()
        profileAssert(removed and empty, "registry-probe-section-deleted")
        if not removed then exit for
    end for
end sub

' Exercise the real registry with the production store, not only fixture JSON.
' This section is newly named and contains public synthetic values exclusively.
sub profileProbeStoreRegistry()
    registry = CreateObject("roRegistry")
    sectionName = "AerioProfileStoreProbe-" + CreateObject("roDeviceInfo").getRandomUUID()
    section = CreateObject("roRegistrySection", sectionName)
    slot = "slot-a"
    ready = section.write("connKey_slot-a", "synthetic-default-key") and section.flush()
    before = loadUserProfileStore(section, slot)
    first = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000001", {id: "2147483648", username: "Alice", user_level: 1}, 100)
    staged = userProfileEnsureDefault(before, first)
    if ready and staged <> invalid
        saved = commitUserProfileStore(section, before, staged, {}, true)
        ready = saved.ok
    else
        ready = false
    end if
    profileAssert(ready, "native-registry-default-migration")
    if ready
        loaded = loadUserProfileStore(section, slot)
        ready = loaded.readOnly <> true
        if ready
            ready = loaded.profiles[0].id = first.id and loaded.profiles[0].userId = 2147483648& and loaded.profiles[0].updatedAt = 0
        end if
        profileAssert(ready, "native-registry-default-id-and-unstamped-roundtrip")
        if ready
            other = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000002", {id: 9, username: "other", user_level: 1}, 101)
            other.isDefault = false
            candidate = copyJson(loaded)
            candidate.profiles.push(other)
            keys = {}
            keys[other.id] = "synthetic-other-key"
            saved = commitUserProfileStore(section, loaded, candidate, keys, true)
            profileAssert(saved.ok and section.read(userProfileKeyName(other.id)) = "synthetic-other-key", "native-registry-own-key-with-roster")
            saved = commitUserProfileStore(section, candidate, candidate, {}, false)
            profileAssert(saved.ok and not section.exists(userProfileKeyName(other.id)), "native-registry-remember-off-deletes-own-key")
            profileAssert(section.read("connKey_slot-a") = "synthetic-default-key", "native-registry-default-key-untouched")
        end if
    end if
    section = invalid
    removed = registry.delete(sectionName)
    removed = registry.flush() and removed
    own = CreateObject("roRegistrySection", sectionName)
    empty = own.getKeyList().count() = 0
    own = invalid
    removed = registry.delete(sectionName) and removed
    removed = registry.flush() and removed
    profileAssert(removed and empty, "native-registry-store-probe-cleaned")
end sub
