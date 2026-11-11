// Stdout is a PRIVATE pipe: public TXT/endpoint fields are consumed in memory,
// never copied to reports. NWConnection mirrors iOS; DNSServiceResolve/GetAddrInfo
// also lets the runner verify Bonjour separately from Mac per-executable LAN access.
import Foundation
import Network
import Darwin
import dnssd

guard CommandLine.arguments.count == 2 else { exit(2) }

final class Resolution: @unchecked Sendable {
    weak var probe: DiscoveryProbe?
    let service: String
    let pk: String
    let name: String
    let kind: String
    let noCode: Bool
    var port: UInt16 = 0
    var refs: [DNSServiceRef] = []

    init(_ probe: DiscoveryProbe, _ service: String, _ pk: String, _ txt: NWTXTRecord) {
        self.probe = probe; self.service = service; self.pk = pk
        name = txt["name"] ?? service; kind = txt["kind"] ?? "tv"
        noCode = txt["code"] == nil && txt["pin"] == nil && txt["secret"] == nil
    }
    func stop() { for ref in refs { DNSServiceRefDeallocate(ref) }; refs.removeAll() }
    func emit(_ event: String, _ host: String) {
        guard let probe, probe.resolutions[service] === self else { return }
        probe.emit(["event": event, "service": service, "host": host, "port": Int(port),
                    "pk": pk, "v": "1", "name": name, "kind": kind, "noCode": noCode])
    }
    func start() {
        guard let probe else { return }
        var ref: DNSServiceRef?
        let status = DNSServiceResolve(&ref, 0, 0, service, "_aeriotv-setup._tcp", "local.", { _, _, interface, error, _, host, port, _, _, context in
            guard error == 0, let host, let context else { return }
            let resolution = Unmanaged<Resolution>.fromOpaque(context).takeUnretainedValue()
            guard let probe = resolution.probe else { return }
            resolution.port = UInt16(bigEndian: port)
            var addressRef: DNSServiceRef?
            let status = DNSServiceGetAddrInfo(&addressRef, 0, interface, DNSServiceProtocol(kDNSServiceProtocol_IPv4), host, { _, flags, _, error, _, address, _, context in
                guard error == 0, flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0, let address,
                      address.pointee.sa_family == sa_family_t(AF_INET), let context else { return }
                let resolution = Unmanaged<Resolution>.fromOpaque(context).takeUnretainedValue()
                let host = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { String(cString: inet_ntoa($0.pointee.sin_addr)) }
                if host == resolution.probe?.expectedIP { resolution.emit("dns-resolved", host) }
            }, context)
            if status == 0, let addressRef { resolution.refs.append(addressRef); DNSServiceSetDispatchQueue(addressRef, probe.queue) }
        }, Unmanaged.passUnretained(self).toOpaque())
        if status == 0, let ref { refs.append(ref); DNSServiceSetDispatchQueue(ref, probe.queue) }
    }
}

final class DiscoveryProbe: @unchecked Sendable {
    let expectedIP: String
    let queue = DispatchQueue(label: "aeriotv.roku.discovery-test")
    var browser: NWBrowser?
    var connections: [String: NWConnection] = [:]
    var resolutions: [String: Resolution] = [:]

    init(_ ip: String) { expectedIP = ip }
    func emit(_ row: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        print(line); fflush(stdout)
    }
    func start() {
        let params = NWParameters.tcp
        params.includePeerToPeer = false
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: "_aeriotv-setup._tcp", domain: nil), using: params)
        browser = b
        b.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.emit(["event": "ready"])
            case .failed, .waiting: self?.emit(["event": "browser-unavailable"])
            default: break
            }
        }
        b.browseResultsChangedHandler = { [weak self] results, _ in self?.apply(results) }
        b.start(queue: queue)
    }
    func apply(_ results: Set<NWBrowser.Result>) {
        var live = Set<String>()
        for result in results {
            guard case let .service(service, _, _, _) = result.endpoint,
                  case let .bonjour(txt) = result.metadata, txt["role"] != "source", txt["v"] == "1",
                  let encoded = txt["pk"], let pk = Data(base64Encoded: encoded), pk.count == 32 else { continue }
            live.insert(service)
            if resolutions[service]?.pk == encoded { continue }
            connections.removeValue(forKey: service)?.cancel()
            resolutions.removeValue(forKey: service)?.stop()
            let resolution = Resolution(self, service, encoded, txt)
            resolutions[service] = resolution
            resolution.start()
            let params = NWParameters.tcp
            if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options { ip.version = .v4 }
            let connection = NWConnection(to: result.endpoint, using: params)
            connections[service] = connection
            connection.stateUpdateHandler = { [weak self, weak connection, weak resolution] state in
                guard let self, let resolution else { return }
                switch state {
                case .ready:
                    let remote = connection?.currentPath?.remoteEndpoint
                    connection?.cancel()
                    guard case let .hostPort(host, port)? = remote, case let .ipv4(address) = host,
                          "\(address)" == self.expectedIP else { self.emit(["event": "nw-ready-other-endpoint"]); return }
                    resolution.port = port.rawValue
                    resolution.emit("resolved", "\(address)")
                case .failed, .waiting:
                    connection?.cancel(); self.emit(["event": "nw-unavailable"])
                default: break
                }
            }
            connection.start(queue: queue)
        }
        for gone in Set(resolutions.keys).subtracting(live) {
            emit(["event": "removed", "service": gone])
            connections.removeValue(forKey: gone)?.cancel()
            resolutions.removeValue(forKey: gone)?.stop()
        }
    }
}

let probe = DiscoveryProbe(CommandLine.arguments[1])
probe.start()
dispatchMain()
