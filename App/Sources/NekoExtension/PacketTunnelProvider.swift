import NetworkExtension
import Network

// IMPORT the models
// If in same module, no import needed

class PacketTunnelProvider: NEPacketTunnelProvider {
    var rules: [DomainRule] = []
    let upstreamDNS = "8.8.8.8"
    
    func startTunnel(options: [String : NSObject]? = nil) {
        loadRules()
        setupTunnel()
    }
    
    func loadRules() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rulesFile = docs.appendingPathComponent("rules.json")
        
        if let data = try? Data(contentsOf: rulesFile),
           let saved = try? JSONDecoder().decode([DomainRule].self, from: data) {
            rules = saved
        }
    }
    
    func setupTunnel() {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        let dns = NEDNSSettings(servers: [upstreamDNS])
        dns.matchDomains = [""]
        settings.dnsSettings = dns
        
        setTunnelNetworkSettings(settings) { error in
            self.readPackets()
        }
    }
    
    func readPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            for packet in packets {
                self?.handlePacket(packet)
            }
            self?.readPackets()
        }
    }
    
    func handlePacket(_ packet: Data) {
        guard let domain = extractDomain(from: packet) else {
            packetFlow.writePackets([packet], withProtocols: [AF_INET as NSNumber])
            return
        }
        
        let shouldBlock = rules.contains { rule in
            rule.isActive && rule.isBlocked && domain.contains(rule.pattern)
        }
        
        // Log it
        saveLog(domain: domain, blocked: shouldBlock)
        
        if shouldBlock {
            let response = createBlockResponse(for: packet)
            packetFlow.writePackets([response], withProtocols: [AF_INET as NSNumber])
        } else {
            packetFlow.writePackets([packet], withProtocols: [AF_INET as NSNumber])
        }
    }
    
    func extractDomain(from packet: Data) -> String? {
        guard packet.count > 12 else { return nil }
        
        var domain = ""
        var index = 12
        
        while index < packet.count {
            let length = Int(packet[index])
            if length == 0 { break }
            
            index += 1
            if index + length <= packet.count,
               let part = String(data: packet[index..<index+length], encoding: .utf8) {
                domain += domain.isEmpty ? part : ".\(part)"
            }
            index += length
        }
        
        return domain.isEmpty ? nil : domain
    }
    
    func createBlockResponse(for query: Data) -> Data {
        var response = query
        if response.count >= 2 {
            response[2] |= 0x84
        }
        return response
    }
    
    func saveLog(domain: String, blocked: Bool) {
        let log = DNSLog(timestamp: Date(), domain: domain, blocked: blocked)
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsFile = docs.appendingPathComponent("logs.json")
        
        var logs: [DNSLog] = []
        if let data = try? Data(contentsOf: logsFile),
           let saved = try? JSONDecoder().decode([DNSLog].self, from: data) {
            logs = saved
        }
        
        logs.insert(log, at: 0)
        if logs.count > 100 {
            logs.removeLast()
        }
        
        if let data = try? JSONEncoder().encode(logs) {
            try? data.write(to: logsFile)
        }
    }
}
