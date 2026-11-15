sub init()
    m.picker = m.top.findNode("picker")
    m.step = 0
    m.failed = false
    m.picker.observeField("intent", "onProbeIntent")
    profileA = {kind: "profile", id: "a", name: "Alexandra — a longer profile name", username: "alex", avatar: {color: "teal"}, locked: false, current: false}
    profileB = {kind: "profile", id: "b", name: "Bob", username: "bob", avatar: {}, locked: true, current: true}
    m.model = {ok: true, show: true, purpose: "launch", focus: 1, back: "exit", tiles: [profileA, profileB, {kind: "add", name: "Add Profile"}]}
    m.picker.model = m.model
    m.picker.setFocus(true)
    timer = m.top.findNode("ready")
    timer.observeField("fire", "onProbeReady")
    timer.control = "start"
end sub

sub onProbeReady()
    print "[picker-probe] "; FormatJson({kind: "ready", focus: m.picker.focusIndex})
end sub

sub onProbeIntent(event as object)
    intent = event.getData()
    expected = ["pin", "close", "reorder", "close", "back"]
    indices = [1, 1, 0, 1, 1]
    if m.step >= expected.count()
        m.failed = true
    else if intent.action <> expected[m.step] or intent.index <> indices[m.step]
        m.failed = true
    end if
    print "[picker-probe] "; FormatJson({kind: "intent", step: m.step, action: intent.action, index: intent.index, passed: not m.failed})
    if m.step = 0
        m.model.purpose = "switcher"
        m.model.back = "close"
        m.model.tiles.push({kind: "manage", name: "Manage Profiles"})
        m.picker.model = m.model
    end if
    if m.step = 3 then m.picker.busy = true
    m.step++
    if m.step = 5 then print "[picker-probe] "; FormatJson({kind: "complete", passed: not m.failed})
end sub
