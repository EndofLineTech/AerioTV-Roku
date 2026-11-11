// Offline macOS Vision regression; synthetic public fixtures only, no device.
import AppKit
import CoreImage
import Foundation

let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("opencode/pairing-ui-test-" + UUID().uuidString).resolvingSymlinksInPath()
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }

func check(_ name: String, _ payload: String?, _ fingerprint: Bool, _ expected: Bool) throws {
    let image = NSImage(size: NSSize(width: 1920, height: 1080))
    image.lockFocus()
    NSColor.black.setFill(); NSRect(x: 0, y: 0, width: 1920, height: 1080).fill()
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 48), .foregroundColor: NSColor.white]
    ("Set up from another device" as NSString).draw(at: NSPoint(x: 130, y: 900), withAttributes: attributes)
    ("PAIRING TEST BUILD - NOT SECURITY QUALIFIED" as NSString).draw(at: NSPoint(x: 130, y: 60), withAttributes: attributes)
    if fingerprint { ("Key ABCD" as NSString).draw(at: NSPoint(x: 130, y: 500), withAttributes: attributes) }
    if let payload {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        let code = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let bitmap = CIContext().createCGImage(code, from: code.extent)!
        NSColor.white.setFill(); NSRect(x: 1090, y: 190, width: 650, height: 650).fill()
        NSGraphicsContext.current!.imageInterpolation = .none
        NSImage(cgImage: bitmap, size: NSSize(width: 600, height: 600)).draw(in: NSRect(x: 1115, y: 215, width: 600, height: 600))
    }
    image.unlockFocus()
    let file = temporary.appendingPathComponent(name + ".png")
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try rep.representation(using: .png, properties: [:])!.write(to: file)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["-module-cache-path", temporary.appendingPathComponent("cache").path, "scripts/read-pairing-ui.swift", file.path]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0,
          let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          result["pairingReady"] as? Bool == expected else {
        fputs("Pairing UI regression failed: \(name)\n", stderr); exit(1)
    }
    print("\(name): passed")
}

try check("live-qr-without-readable-fingerprint", "aeriotv://setup?v=1&ip=192.0.2.10&port=32123&code=123456&pk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&name=Fixture", false, true)
try check("fingerprint-without-qr-is-not-ready", nil, true, false)
try check("unrelated-qr-is-not-ready", "https://example.invalid/", true, false)
try check("wrong-wire-version-is-not-ready", "aeriotv://setup?v=2", true, false)
