// Offline, allowlisted UI classification. Never print OCR text or account data.
import Foundation
import Vision

guard CommandLine.arguments.count == 2 else { exit(2) }
do {
    let request = VNRecognizeTextRequest()
    let barcode = VNDetectBarcodesRequest()
    barcode.symbologies = [.qr]
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    try VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[1])).perform([request, barcode])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string.lowercased() }
    let text = lines.joined(separator: " ")
    // Readiness is the real QR, not OCR of a random four-character fingerprint
    // (Vision can confuse 0/O or 1/I and otherwise hide a healthy live session).
    let setupQr = (barcode.results ?? []).contains { result in
        guard let value = result.payloadStringValue, let link = URLComponents(string: value) else { return false }
        return link.scheme == "aeriotv" && link.host == "setup" && link.queryItems?.contains { $0.name == "v" && $0.value == "1" } == true
    }
    var result: [String: Any] = [
        "welcome": text.contains("welcome to aeriotv"),
        "setup": text.contains("forget connection") && text.contains("connect"),
        "guide": text.contains("live tv") && text.contains("settings"),
        "settingsHub": text.contains("open connection settings"),
        "picker": text.contains("select dispatcharr connection"),
        "manager": text.contains("manage saved connections") && text.contains("add dispatcharr connection"),
        "pairing": text.contains("set up from another device"),
        "pairingReady": text.contains("set up from another device") && setupQr,
        "preparing": text.contains("preparing a secure setup code"),
        "unavailable": text.contains("setup is not available"),
        "warning": text.contains("pairing test build") && text.contains("not security"),
        "verificationFailed": text.contains("could not verify the playlist") && text.contains("saved connections were not changed"),
        "retry": text.contains("try again")
    ]
    let regex = try NSRegularExpression(pattern: #"\(([1-4]) saved\)"#)
    for line in lines {
        let range = NSRange(line.startIndex..., in: line)
        if let match = regex.firstMatch(in: line, range: range), let number = Range(match.range(at: 1), in: line) {
            result["connectionCount"] = Int(line[number])
        }
    }
    if text.contains("add a connection") && result["connectionCount"] == nil { result["connectionCount"] = 0 }
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
} catch {
    fputs("Pairing UI classification failed\n", stderr)
    exit(1)
}
