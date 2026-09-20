' Conservative text-language preference, not translation or audio-language inference.
' Unknown/short/mixed text remains explicitly unconfirmed.
function descriptionLanguage(text as string) as string
    normalized = " " + CreateObject("roRegex", "[^a-zà-ÿ]+", "i").replaceAll(lcase(text), " ") + " "
    english = descriptionWordScore(normalized, ["the", "and", "with", "who", "from", "their", "this", "into", "about", "after", "while", "when", "are", "his", "her", "they", "must", "has", "that", "them", "out", "where"])
    french = descriptionWordScore(normalized, ["les", "une", "dans", "avec", "pour", "qui", "est", "son", "ses", "des", "du", "sur", "elle", "lui", "aux", "et", "le", "la", "de", "au"])
    german = descriptionWordScore(normalized, ["der", "die", "das", "und", "ist", "eine", "einer", "von", "sich", "den", "dem", "sie"])
    spanish = descriptionWordScore(normalized, ["los", "las", "una", "con", "para", "del", "que", "sus", "pero", "por", "el", "en", "se"])
    if english >= 3 and english >= french + 2 and english >= german + 2 and english >= spanish + 2 then return "en"
    if french >= 3 and french >= english + 2 then return "other"
    if german >= 3 and german >= english + 2 then return "other"
    if spanish >= 3 and spanish >= english + 2 then return "other"
    return "unknown"
end function

function descriptionWordScore(text as string, words as object) as integer
    score = 0
    for each word in words
        if instr(1, text, " " + word + " ") > 0 then score++
    end for
    return score
end function

function preferredDescription(original as string, candidate as string) as string
    if original = "" then return candidate
    if descriptionLanguage(original) = "en" then return original
    if descriptionLanguage(candidate) = "en" then return candidate
    return original
end function

function providerEnglishDescription(rows as dynamic) as string
    if type(rows) <> "roArray" then return ""
    for each row in rows
        if type(row) = "roAssociativeArray"
            props = row.custom_properties
            if type(props) = "roAssociativeArray"
                containers = [props]
                for each field in ["basic_data", "detailed_info", "info"]
                    if type(props[field]) = "roAssociativeArray" then containers.push(props[field])
                end for
                for each container in containers
                    for each field in ["description_en", "plot_en", "overview_en", "description", "plot", "overview"]
                        text = left(textValue(container[field]), 2000)
                        if descriptionLanguage(text) = "en" then return text
                    end for
                end for
            end if
        end if
    end for
    return ""
end function
