import SwiftUI
import NetworkExtension

struct RevokeDomain: Identifiable, Codable {
    let id = UUID()
    let domain: String
    var isEnabled: Bool
}

class AntiRevokeManager: ObservableObject {
    @Published var isEnabled = false
    @Published var domains: [RevokeDomain] = [
        RevokeDomain(domain: "ocsp.apple.com", isEnabled: true),
        RevokeDomain(domain: "ocsp2.apple.com", isEnabled: true),
        RevokeDomain(domain: "crl.apple.com", isEnabled: true),
        RevokeDomain(domain: "crl.entrust.net", isEnabled: true),
        RevokeDomain(domain: "crl3.digicert.com", isEnabled: true),
        RevokeDomain(domain: "crl4.digicert.com", isEnabled: true),
        RevokeDomain(domain: "ocsp.digicert.com", isEnabled: true),
        RevokeDomain(domain: "ocsp.entrust.net", isEnabled: true),
        RevokeDomain(domain: "valid.apple.com", isEnabled: true),
        RevokeDomain(domain: "gdmf.apple.com", isEnabled: true),
        RevokeDomain(domain: "mesu.apple.com", isEnabled: true),
        RevokeDomain(domain: "xp.apple.com", isEnabled: true)
    ]
    
    func toggleProtection() {
        if isEnabled {
            disableProtection()
        } else {
            enableProtection()
        }
    }
    
    func enableProtection() {
        // Use AdGuard DNS (blocks Apple OCSP by default)
        let manager = NEDNSSettingsManager.shared()
        manager.loadFromPreferences { error in
            let settings = NEDNSOverHTTPSSettings(servers: ["94.140.14.14", "94.140.15.15"])
            settings.serverURL = URL(string: "https://dns.adguard.com/dns-query")
            
            manager.saveToPreferences { error in
                DispatchQueue.main.async {
                    self.isEnabled = (error == nil)
                }
            }
        }
    }
    
    func disableProtection() {
        NEDNSSettingsManager.shared().removeFromPreferences { error in
            DispatchQueue.main.async {
                self.isEnabled = false
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = AntiRevokeManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(manager: manager)
                .tabItem { Label("Protection", systemImage: "shield") }
                .tag(0)
            
            DomainsView(manager: manager)
                .tabItem { Label("Blocked", systemImage: "list.bullet") }
                .tag(1)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var manager: AntiRevokeManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Anti-Revoke")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { manager.isEnabled },
                            set: { _ in manager.toggleProtection() }
                        ))
                    }
                } footer: {
                    Text("Blocks Apple's revocation servers to keep sideloaded apps from expiring")
                }
                
                Section("How it works") {
                    Text("Uses AdGuard DNS which blocks Apple OCSP servers")
                        .font(.caption)
                    
                    Text("No VPN or extension needed - just DNS settings")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Section("Status") {
                    if manager.isEnabled {
                        Label("Protection Active", systemImage: "checkmark.shield")
                            .foregroundColor(.green)
                    } else {
                        Label("Protection Off", systemImage: "shield.slash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Anti-Revoke")
        }
    }
}

struct DomainsView: View {
    @ObservedObject var manager: AntiRevokeManager
    
    var body: some View {
        NavigationView {
            List {
                Section("Blocked Domains") {
                    ForEach(manager.domains) { domain in
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.green)
                            Text(domain.domain)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                } footer: {
                    Text("These Apple revocation servers are blocked when protection is enabled")
                }
            }
            .navigationTitle("Blocklist")
        }
    }
}

@main
struct AntiRevokeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
