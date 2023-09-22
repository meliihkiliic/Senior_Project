import SwiftUI
import SocketIO

struct User: Hashable, Codable {
    let name: String
}

struct Message: Hashable, Identifiable, Codable {
    var id = UUID()
    let user: User
    let text: String
    let room: String
}

struct ChatRoomListView: View {
    @State private var selectedRoom: String = ""
    @State private var rooms: [String] = ["Genel", "Alkol", "Sigara", "Kumar", "Teknoloji", "Alışveriş", "Kafein","Yeme", "İlişki",  "Eroin", "Kokain", "Esrar"]
    
    var body: some View {
        NavigationView {
            List(rooms, id: \.self) { room in
                NavigationLink(destination: ChatRoomView(room: room)) {
                    Text(room)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Chat Odaları")
        }
    }
}

struct ChatRoomView: View {
    @StateObject private var chatManager = ChatManager()
    let room: String
    
    @State private var timer: Timer? = nil

    
    var filteredMessages: [Message] {
        chatManager.messages.filter { $0.room == room }.reversed()
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredMessages) { msg in
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(msg.user.name.prefix(1)).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray)
                                    .cornerRadius(20)
                                
                                VStack(alignment: .leading) {
                                    Text(msg.user.name)
                                        .fontWeight(.bold)
                                    
                                    Text(msg.text)
                                }
                            }
                            .id(msg.id)
                            .padding()
                            .background(Color.white)
                            .frame(width: geometry.size.width, alignment: .leading)
                        }
                    }
                }
                .padding(.leading)
                .frame(maxWidth: .infinity)
                
                HStack {
                    TextField("Mesajınızı girin", text: $chatManager.message)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        chatManager.sendMessage(message: chatManager.message, room: room)
                        chatManager.message = ""
                        chatManager.disconnect()
                        chatManager.connect(room: room, receiveMessage: receiveMessage)
                    }) {
                        Text("Gönder")
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.blue)
                            .cornerRadius(5)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(10)
            .navigationBarTitle("\(room) Chat")
            .onAppear {
                chatManager.connect(room: room, receiveMessage: receiveMessage)
                startTimer()  // Start timer when view appears
            }
            .onDisappear {
                chatManager.disconnect()
                cancelTimer()  // Cancel timer when view disappears
            }
        }
    }

    
    func receiveMessage(_ message: Message) {
        DispatchQueue.main.async {
            chatManager.messages.insert(message, at: 0)
        }
    }
    
    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            chatManager.disconnect()
            chatManager.connect(room: room, receiveMessage: receiveMessage)
            
        }
    }

}

class ChatManager: ObservableObject {
    @Published var message: String = ""
    @Published var messages: [Message] = []
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var receiveMessage: ((Message) -> Void)?
    
    init() {
        manager = SocketManager(socketURL: URL(string: "http://localhost:3001")!, config: [.log(true), .compress])
        socket = manager?.defaultSocket
    }
    
    func connect(room: String, receiveMessage: @escaping (Message) -> Void) {
        self.receiveMessage = receiveMessage
        
        print("Bağlantı kuruluyor...")
        socket?.connect()
        
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            
            print("Bağlantı başarılı!")
            
            // Kullanıcı adını sunucuya gönder
            if let userName = UserDefaults.standard.string(forKey: "userName") {
                self.sendUserName(userName)
            }
            // Belirli bir odaya katıl
            self.joinRoom(room)
        }
        // Mesajları almak için "message" olayını dinle
        socket?.on("messages") { [weak self] data, _ in
            guard let messagesData = data.first as? [[String: Any]] else {
                return
            }
            let messages = messagesData.compactMap { messageData -> Message? in
                guard let room = messageData["room"] as? String,
                      let text = messageData["text"] as? String,
                      let user = messageData["user"] as? [String: Any],
                      let username = user["name"] as? String else {
                    return nil
                }
                let userObject = User(name: username)
                return Message(user: userObject, text: text, room: room)
            }
            DispatchQueue.main.async {
                self?.messages = messages
            }
        }
        socket?.on(clientEvent: .disconnect) { data, ack in
            print("Bağlantı kesildi!")
        }
    }
    
    func disconnect() {
        print("Bağlantı kapatılıyor...")
        socket?.disconnect()
    }
    
    func sendUserName(_ userName: String) {
        print("Kullanıcı adı gönderiliyor...")
        socket?.emit("username", with: [userName], completion: {
            print("Kullanıcı adı gönderme tamamlandı.")
        })
    }
    
    
    func joinRoom(_ room: String) {
        print("Odaya katılıyor: \(room)")
        socket?.emit("joinRoom", with: [room], completion: {
            print("Odaya katılma tamamlandı.")
        })
    }
    
    func sendMessage(message: String, room: String) {
        print("Mesaj gönderiliyor: \(message)")
        let data: [String: Any] = [
            "message": message,
            "room": room
        ]
        socket?.emit("send", with: [data], completion: {
            print("Mesaj gönderme tamamlandı.")
        })
    }
}

struct denemeView: View {
    var body: some View {
        ChatRoomListView()
    }
}

struct denemeView_Previews: PreviewProvider {
    static var previews: some View {
        denemeView()
    }
}
