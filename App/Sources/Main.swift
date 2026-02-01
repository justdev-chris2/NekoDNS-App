import SwiftUI

struct Message: Identifiable, Codable {
    var id = UUID()
    let user: String
    let text: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, user, text, timestamp
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.user)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(18)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }
}

@main
struct TempleChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isConnected = false
    @Published var connectionError: String?
    
    private var socket: URLSessionWebSocketTask?
    private var username = "Anon"
    
    func setUsername(_ name: String) {
        username = name
    }
    
    func connect() {
        guard let url = URL(string: "wss://temple-chat-backend.onrender.com/ws") else {
            connectionError = "Invalid URL"
            return
        }
        
        let request = URLRequest(url: url)
        socket = URLSession.shared.webSocketTask(with: request)
        socket?.resume()
        isConnected = true
        connectionError = nil
        
        receiveMessages()
    }
    
    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
    
    private func receiveMessages() {
        socket?.receive { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    if case .string(let text) = message,
                       let data = text.data(using: .utf8),
                       let decodedMessage = try? JSONDecoder().decode(Message.self, from: data) {
                        self.messages.append(decodedMessage)
                    }
                    self.receiveMessages()
                    
                case .failure(let error):
                    print("Receive error: \(error)")
                    self.isConnected = false
                    self.connectionError = "Connection lost"
                }
            }
        }
    }
    
    func sendMessage(_ text: String) {
        guard !text.isEmpty, isConnected else { return }
        
        let message = Message(
            user: username,
            text: text,
            timestamp: Date()
        )
        
        // Optimistic update
        messages.append(message)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(message)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            socket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("Send error: \(error)")
                }
            }
        } catch {
            print("Encode error: \(error)")
        }
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var newMessage = ""
    @State private var showUsernamePrompt = true
    @State private var username = "Anon"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Epsteins Kids Locked In His Temple")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Connection status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.user == username
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                
                // Connection error
                if let error = viewModel.connectionError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                            .font(.caption)
                        Spacer()
                        Button("Retry") {
                            viewModel.connect()
                        }
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                }
                
                // Input
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField("Message...", text: $newMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .frame(width: 44, height: 44)
                                .background(newMessage.isEmpty ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .disabled(newMessage.isEmpty || !viewModel.isConnected)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert("Enter Name", isPresented: $showUsernamePrompt) {
            TextField("Username", text: $username)
            Button("OK") {
                showUsernamePrompt = false
                viewModel.setUsername(username)
            }
        }
    }
    
    private func sendMessage() {
        let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        viewModel.sendMessage(messageText)
        newMessage = ""
    }
}
