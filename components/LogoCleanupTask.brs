sub init()
    m.top.functionName = "cleanFiles"
end sub

sub cleanFiles()
    fs = CreateObject("roFileSystem")
    allowed = CreateObject("roRegex", "^tmp:/aeriotv-logos-[A-Za-z0-9-]+\.(part|png|jpg|webp)$", "")
    for each path in m.top.paths
        if allowed.isMatch(path) then fs.delete(path)
    end for
    m.top.done = true
end sub
