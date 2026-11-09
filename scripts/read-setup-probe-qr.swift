// Offline decoder used only on the synthetic receiver's screenshot. The caller
// captures stdout privately, validates the link, and never prints its contents.
import Foundation
import Vision

guard CommandLine.arguments.count == 2 else { exit(2) }
let request = VNDetectBarcodesRequest()
request.symbologies = [.qr]
do {
    try VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[1])).perform([request])
    guard let value = request.results?.first?.payloadStringValue else { exit(3) }
    print(value)
} catch {
    fputs("QR image could not be decoded\n", stderr)
    exit(1)
}
