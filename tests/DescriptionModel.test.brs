sub main()
    english = "The crew and their captain must find the visitor who arrived from another world."
    french = "La station est dans une zone de conflit avec les peuples qui vivent sur la planète."
    german = "Die Station ist eine Basis der Flotte und sie wurde von den Menschen gebaut."
    if descriptionLanguage(english) <> "en" then stop
    if descriptionLanguage(french) <> "other" or descriptionLanguage(german) <> "other" then stop
    if descriptionLanguage("The Matrix") <> "unknown" then stop
    if preferredDescription(english, french) <> english then stop
    if preferredDescription(french, english) <> english then stop
    if preferredDescription(french, "Short text") <> french then stop
    rows = [{custom_properties: {basic_data: {plot: german}}}, {custom_properties: {basic_data: {plot: english}}, stream_url: "private"}]
    if providerEnglishDescription(rows) <> english then stop
    if providerEnglishDescription([{custom_properties: {basic_data: {original_language: "en", plot: french}}}]) <> "" then stop
    print "ALL TESTS PASSED"
end sub
