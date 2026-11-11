// Offline review aid: composites only the synthetic captures named in a manifest.
// Does not capture the device, perform OCR, or imply visual approval.
import AppKit
import Foundation

struct Capture: Decodable { let file: String }
struct Manifest: Decodable { let captures: [Capture] }

guard CommandLine.arguments.count == 2 else {
    fatalError("Supply a synthetic UI audit captures.json")
}
let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
let directory = manifestURL.deletingLastPathComponent().appendingPathComponent("review")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let width = 1920, cellWidth = 960, cellHeight = 576, height = cellHeight * 3
for start in stride(from: 0, to: manifest.captures.count, by: 6) {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    for index in start..<min(start + 6, manifest.captures.count) {
        let file = manifest.captures[index].file
        guard let image = NSImage(contentsOfFile: file) else { fatalError("Missing synthetic capture") }
        let cell = index - start
        let x = (cell % 2) * cellWidth, y = height - (cell / 2 + 1) * cellHeight
        image.draw(in: NSRect(x: x, y: y, width: cellWidth, height: 540))
        let label = "\(index + 1). \(URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent)"
        (label as NSString).draw(at: NSPoint(x: x + 8, y: y + 548), withAttributes: [
            .font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.white])
    }
    NSGraphicsContext.restoreGraphicsState()
    let output = directory.appendingPathComponent(String(format: "sheet-%02d.jpg", start / 6 + 1))
    try bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: output)
    print(output.path)
}
