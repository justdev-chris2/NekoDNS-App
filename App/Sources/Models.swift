import Foundation

struct DomainRule: Identifiable, Codable {
    let id = UUID()
    var pattern: String
    var isBlocked: Bool
    var isActive: Bool
}

struct DNSLog: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let domain: String
    let blocked: Bool
}
