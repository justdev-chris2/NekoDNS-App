import Foundation

struct DomainRule: Identifiable, Codable {
    var id = UUID()
    var pattern: String
    var isBlocked: Bool
    var isActive: Bool
}

struct DNSLog: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let domain: String
    let blocked: Bool
}
