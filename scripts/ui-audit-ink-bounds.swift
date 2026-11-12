// Offline optical-centering check for explicitly bounded synthetic controls.
// Input regions deliberately exclude icons and rounded edges. This is NOT OCR
// or an automatic visual pass; inspect the image and interpret the ink bounds.
import AppKit
import Foundation

struct Region: Decodable {
    let name: String, file: String, ink: String
    let pill: [Double]
    let crop: [Int]
}
guard CommandLine.arguments.count == 2 else { fatalError("Supply regions JSON") }
let regions = try JSONDecoder().decode([Region].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var results: [[String: Any]] = []
for region in regions {
    guard region.pill.count == 4, region.crop.count == 4,
          let image = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: region.file))) else { fatalError("Invalid region/image") }
    let c = region.crop, p = region.pill
    guard c[0] >= 0, c[1] >= 0, c[2] > 0, c[3] > 0,
          c[0] + c[2] <= image.pixelsWide, c[1] + c[3] <= image.pixelsHigh,
          ["dark", "light"].contains(region.ink) else { fatalError("Region outside image or unknown ink") }
    var left = image.pixelsWide, top = image.pixelsHigh, right = -1, bottom = -1
    for y in c[1]..<(c[1] + c[3]) {
        for x in c[0]..<(c[0] + c[2]) {
            guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            let r = color.redComponent, g = color.greenComponent, b = color.blueComponent
            let ink = region.ink == "dark" ? (r < 0.25 && g < 0.38 && b < 0.46) : (r > 0.48 && g > 0.54 && b > 0.58)
            if ink { left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y) }
        }
    }
    guard right >= left else { fatalError("No ink in region") }
    results.append(["name": region.name, "file": region.file, "inkBounds": [left, top, right - left + 1, bottom - top + 1],
        "horizontalOffsetPx": Double(left + right + 1) / 2 - (Double(p[0]) + Double(p[2]) / 2),
        "verticalOffsetPx": Double(top + bottom + 1) / 2 - (Double(p[1]) + Double(p[3]) / 2)])
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
