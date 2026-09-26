sub init()
    m.sectionBackground = m.top.findNode("sectionBackground")
    m.sectionTitle = m.top.findNode("sectionTitle")
    m.itemTitle = m.top.findNode("itemTitle")
    uiSetColor(m.sectionBackground, "0x17344AFF")
    uiSetColor(m.sectionTitle, "0x1AC4D8FF")
    uiSetColor(m.itemTitle, "0xE8F3FAFF")
end sub

sub onDvrListRowContent()
    if m.itemTitle = invalid or m.top.itemContent = invalid then return
    heading = m.top.itemContent.shortDescriptionLine1 = "heading"
    m.sectionBackground.visible = heading
    m.sectionTitle.visible = heading
    m.itemTitle.visible = not heading
    if heading
        m.sectionTitle.text = m.top.itemContent.title
    else
        m.itemTitle.text = m.top.itemContent.title
    end if
end sub
