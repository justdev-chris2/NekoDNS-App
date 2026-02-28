import SwiftUI
import NetworkExtension

// REMOVE DomainRule and DNSLog from here - they're now in Models.swift

class NekoManager: ObservableObject {
    @Published var rules: [DomainRule] = []
    @Published var logs: [DNSLog] = []
    @Published var isEnabled = false
    @Published var statsTotal = 0
    @Published var statsBlocked = 0
    
    let rulesFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("rules.json")
    
    let logsFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("logs.json")
    
    init() {
        loadRules()
        loadLogs()
    }
    
    func loadRules() {
        guard let data = try? Data(contentsOf: rulesFile),
              let saved = try? JSONDecoder().decode([DomainRule].self, from: data) else { return }
        rules = saved
    }
    
    func saveRules() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        try? data.write(to: rulesFile)
    }
    
    func addRule(pattern: String, isBlocked: Bool) {
        let rule = DomainRule(pattern: pattern.lowercased(), isBlocked: isBlocked, isActive: true)
        rules.append(rule)
        saveRules()
    }
    
    func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }
    
    func toggleRule(_ rule: DomainRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isActive.toggle()
            saveRules()
        }
    }
    
    func loadLogs() {
        guard let data = try? Data(contentsOf: logsFile),
              let saved = try? JSONDecoder().decode([DNSLog].self, from: data) else { return }
        logs = saved
    }
    
    func saveLogs() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        try? data.write(to: logsFile)
    }
    
    func toggleFilter() {
        if isEnabled {
            stopFilter()
        } else {
            startFilter()
        }
    }
    
    func startFilter() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            let manager = managers?.first ?? NETunnelProviderManager()
            manager.localizedDescription = "NekoDNS"
            
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.justdev-chris.NekoDNS.NekoExtension"
            proto.serverAddress = "127.0.0.1"
            manager.protocolConfiguration = proto
            manager.isEnabled = true
            
            manager.saveToPreferences { error in
                if error == nil {
                    try? manager.connection.startVPNTunnel()
                    DispatchQueue.main.async {
                        self?.isEnabled = true
                    }
                }
            }
        }
    }
    
    func stopFilter() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            managers?.first?.connection.stopVPNTunnel()
            DispatchQueue.main.async {
                self.isEnabled = false
            }
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var manager = NekoManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(manager: manager)
                .tabItem { Label("Dashboard", systemImage: "gauge") }
                .tag(0)
            
            RulesView(manager: manager)
                .tabItem { Label("Rules", systemImage: "list.bullet") }
                .tag(1)
            
            LogsView(manager: manager)
                .tabItem { Label("Logs", systemImage: "doc.text") }
                .tag(2)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var manager: NekoManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(manager.isEnabled ? "Active" : "Inactive")
                            .foregroundColor(manager.isEnabled ? .green : .red)
                    }
                    
                    Button(manager.isEnabled ? "Stop Filter" : "Start Filter") {
                        manager.toggleFilter()
                    }
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Queries")
                        Spacer()
                        Text("\(manager.statsTotal)")
                    }
                    HStack {
                        Text("Blocked")
                        Spacer()
                        Text("\(manager.statsBlocked)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("NekoDNS")
        }
    }
}

struct RulesView: View {
    @ObservedObject var manager: NekoManager
    @State private var newPattern = ""
    @State private var isBlocked = true
    @State private var showAdd = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.rules) { rule in
                    HStack {
                        Image(systemName: rule.isBlocked ? "nosign" : "checkmark.circle")
                            .foregroundColor(rule.isBlocked ? .red : .green)
                        
                        Text(rule.pattern)
                            .strikethrough(!rule.isActive)
                        
                        Spacer()
                        
                        Button {
                            manager.toggleRule(rule)
                        } label: {
                            Image(systemName: rule.isActive ? "pause" : "play")
                        }
                    }
                }
                .onDelete(perform: manager.deleteRule)
            }
            .navigationTitle("Rules")
            .toolbar {
                Button("Add") { showAdd = true }
            }
            .sheet(isPresented: $showAdd) {
                NavigationView {
                    Form {
                        TextField("example.com", text: $newPattern)
                            .autocapitalization(.none)
                        
                        Picker("Action", selection: $isBlocked) {
                            Text("Block").tag(true)
                            Text("Allow").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .navigationTitle("New Rule")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if !newPattern.isEmpty {
                                    manager.addRule(pattern: newPattern, isBlocked: isBlocked)
                                    newPattern = ""
                                    showAdd = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LogsView: View {
    @ObservedObject var manager: NekoManager
    
    var body: some View {
        NavigationView {
            List(manager.logs) { log in
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: log.blocked ? "nosign" : "checkmark")
                            .foregroundColor(log.blocked ? .red : .green)
                        Text(log.domain)
                    }
                    Text(log.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Logs")
        }
    }
}

@main
struct NekoDNSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
