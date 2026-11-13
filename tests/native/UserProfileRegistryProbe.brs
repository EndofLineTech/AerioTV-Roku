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
