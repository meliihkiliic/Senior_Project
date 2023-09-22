

import SwiftUI
import PhotosUI
import Alamofire
import SwiftyJSON

struct Post: Codable, Identifiable {
    let id: Int64
    let userId: Int64
    let userName: String
    let title: String
    let text: String
    let filter: String
    let imageData: Data?
    var postLikes: [PostLike]
}

struct PostLike: Codable {
    let id: Int64
    let userId: Int64
    let postId: Int64
}

struct homeView: View {
    @State var posts: [Post] = []
    @Binding var isLoggedIn: Bool
    @State var selectedFilter: String? = nil
    let filters = ["Sigara", "Alkol", "Uyuşturucu", "Kumar", "Teknoloji"]
    
    var body: some View {
        if isLoggedIn {
            NavigationView {
                VStack {
                    Spacer().frame(height: 2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(filters, id: \.self) { filter in
                                Button(action: {
                                    if selectedFilter == filter {
                                        selectedFilter = nil
                                    } else {
                                        selectedFilter = filter
                                    }
                                }) {
                                    VStack {
                                        Image(filter)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                            .background(selectedFilter == filter ? Color.blue : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(25)
                                            
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 25)
                                                    .stroke(selectedFilter == filter ? Color.blue : Color.gray, lineWidth: 2)
                                                    .frame(width: 50, height: 50) // Specify frame size here
                                            )
                                        Text(filter) // Yeni satır
                                                    .font(.caption) // Yeni satır
                                                    .foregroundColor(.black) // Yeni satır
                                    }
                                }
                                .background(
                                    Image("backgroundImage")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                                        .opacity(0.5)
                                        .clipped()
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .background(Color.white)
                    List(posts.reversed()) { post in
                        // Postların filtrelenmesi
                        if selectedFilter == nil || post.filter == selectedFilter {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(post.userName)
                                        .font(.title2)
                                    Spacer()
                                }
                                VStack(alignment: .leading){
                                    if let imageData = post.imageData, let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipped()
                                    }
                                    Text(post.title)
                                        .font(.headline)
                                    Text(post.text)
                                        .font(.subheadline)
                                }
                                .padding(.leading, 5) // Add padding to the left side
                                NavigationLink(destination: CommentView(post: post)) {
                                    Text("Yorumları Görüntüle")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Button(action: {
                                self.handleLike(for: post)
                            }) {
                                Image(systemName: isPostLiked(post) ? "heart.fill" : "heart")
                                    .foregroundColor(isPostLiked(post) ? .red : .gray)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        loadData()
                    }
                    
                    .navigationBarTitle("Anasayfa", displayMode: .inline)
                    .navigationBarItems(trailing:
                                            NavigationLink(destination: postCreateView(postCreatedHandler: handlePostCreated)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                                        //buraya (sol üst köşe) profil fotosu gelecek
                    )
                }
                .onAppear {
                    // Load the feed data when the view appears
                    loadData()
                }
            }
        } else {
            ContentView()
                .transition(.slide)
        }
    }
    
    
    
    func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("UserDefaults cleared")
        isLoggedIn = false
        loadData()
    }
    
    func handleLike(for post: Post) {
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        
        if let likeId = posts.first(where: { $0.id == post.id })?.postLikes.first(where: { $0.userId == userId })?.id {
            if isPostLiked(post) {
                deleteLike(id: likeId)
                toggleLike(for: post)
            } else {
                saveLike(for: post)
                toggleLike(for: post)
            }
        } else {
            saveLike(for: post)
            toggleLike(for: post)
        }
    }
    
    
    
    
    func isPostLiked(_ post: Post) -> Bool {
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            return posts[index].postLikes.contains(where: { $0.userId == userId })
        }
        
        return false
    }
    
    
    func toggleLike(for post: Post) {
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            if let likeIndex = posts[index].postLikes.firstIndex(where: { $0.userId == userId }) {
                posts[index].postLikes.remove(at: likeIndex)
            } else {
                let like = PostLike(id: 0, userId: Int64(userId), postId: post.id)
                posts[index].postLikes.append(like)
            }
        }
    }
    
    
    func saveLike(for post: Post) {
        guard let url = URL(string: "http://localhost:8080/likes") else {
            print("Geçersiz URL")
            return
        }
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        let token = UserDefaults.standard.string(forKey: "tokenKey") ?? ""
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "postId": post.id,
            "userId": userId,
        ]
        print("postId: \(post.id)")
        print("userId: \(userId)")
        let jsonData = try? JSONSerialization.data(withJSONObject: body)
        do {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(token, forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
        } catch let error {
            print(String(describing: error))
            print("Hata: \(error.localizedDescription)")
            return
        }
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print(String(describing: error))
                print("İstek hatası: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("Dönüş kodu: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                }
            }
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    print("Yanıt: \(json)")
                } catch let error {
                    print(String(describing: error))
                    print("Yanıt işleme hatası: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    func deleteLike(id: Int64) {
        guard let url = URL(string: "http://localhost:8080/likes/\(id)") else {
            print("Error: Invalid URL")
            return
        }
        let token = UserDefaults.standard.string(forKey: "tokenKey") ?? ""
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            guard let response = response as? HTTPURLResponse else {
                print("Error: Invalid response")
                return
            }
            if response.statusCode == 200 {
                print("Success: Like deleted")
            } else {
                print("Error: Server returned status code \(response.statusCode)")
            }
        }.resume()
    }
    
    
    
    func loadData() {
        let url = URL(string: "http://localhost:8080/posts")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedPosts = try? decoder.decode([Post].self, from: data) {
                    DispatchQueue.main.async {
                        self.posts = decodedPosts
                    }
                    return
                }
            }
            print("Error loading feed data")
        }.resume()
    }
    
    
    func handlePostCreated() {
        loadData()
    }
}



struct home_Previews: PreviewProvider {
    static var previews: some View {
        controller(isLoggedIn: .constant(true))
    }
}

struct postCreateView: View {
    // Define properties to hold the user input for the new post
    @State private var title = ""
    @State private var text = ""
    @State private var postCreated = false
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    let postCreatedHandler: () -> Void

    
    var availableTags = ["Sigara", "Alkol", "Uyuşturucu", "Kumar", "Teknoloji"] // Mevcut etiketlerin bir dizisi
    @State private var selectedTag = "" // Seçilen etiketi tutan değişken
    // Array to store selected photos
    @State private var selectedPhotos = [UIImage]()
    // Bool to track if the photo picker is presented or not
    @State private var isShowingPhotoPicker = false
    
    
    var body: some View {
        // Create a form to allow the user to create a new post
        Form {
            Section(header: Text("Başlık")) {
                TextField("Paylaşımın için başlık gir", text: $title)
            }
            Section(header: Text("İçerik")) {
                TextEditor(text: $text)
            }
            Section(header: Text("Fotoğraf Seç")) {
                Button(action: {
                    isShowingPhotoPicker = true
                }) {
                    Text("Fotoğraf Seç")
                }
                .sheet(isPresented: $isShowingPhotoPicker) {
                    ImagePicker(selectedPhotos: $selectedPhotos)
                }
                
                // Display selected photos
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(selectedPhotos, id: \.self) { photo in
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        }
                    }
                }
            }
            
            Section(header: Text("Etiket")) {
                Picker("Etiket Seç", selection: $selectedTag) {
                    ForEach(availableTags, id: \.self) { tag in
                        Text(tag)
                    }
                }
            }
            Section {
                Button(action: {
                    // Save the new post to the server
                    savePost()
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack{
                        Spacer()
                        Text("Paylaş")
                        Spacer()
                        
                    }
                }
                .disabled(title.isEmpty || text.isEmpty || selectedTag.isEmpty )
            }
        }
        .navigationBarTitle("Yeni gönderi")
    }
    
    
    struct ImagePicker: UIViewControllerRepresentable {
        @Environment(\.presentationMode) var presentationMode
        @Binding var selectedPhotos: [UIImage]
        
        func makeUIViewController(context: Context) -> PHPickerViewController {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }
        
        class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: ImagePicker
            
            init(parent: ImagePicker) {
                self.parent = parent
            }
            
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                parent.presentationMode.wrappedValue.dismiss()
                
                for result in results {
                    if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                        result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                            if let image = image as? UIImage {
                                DispatchQueue.main.async {
                                    self.parent.selectedPhotos.append(image)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func savePost() {
        let url = URL(string: "http://localhost:8080/posts")!
        
        let defaults = UserDefaults.standard
        let userId = defaults.object(forKey: "currentUser") as? Int64 ?? 0
        let token = UserDefaults.standard.string(forKey: "tokenKey") ?? ""
        
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = NSMutableData()
        
        // User ID
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        
        // Title
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(title)\r\n".data(using: .utf8)!)
        
        // Text
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(text)\r\n".data(using: .utf8)!)
        
        // Filter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filter\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(selectedTag)\r\n".data(using: .utf8)!)
        
        // Images
        for (index, image) in selectedPhotos.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.5) {
                let fileName = "image\(index).jpeg"
                let mimeType = "image/jpeg"
                let fieldName = "imageFile"
                
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body as Data
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("Post Created")
                    
                    postCreatedHandler()
                    // Set the postCreated flag to true
                    postCreated = true
                } else {
                    print("Error: \(httpResponse.statusCode)")
                }
            }
        }
        
        task.resume()
    }
    
}

struct Comment: Codable, Identifiable {
    let id: Int64
    let userId: Int64
    let text: String
    let userName: String
}


struct CommentView: View {
    let post: Post
    @State private var comments = [Comment]()
    @State private var newCommentText = ""
    @State private var commentCreated = false
    
    
    var body: some View {
        VStack {
            List(comments, id: \.id) { comment in
                VStack(alignment: .leading) {
                    Text("~\(comment.userName)~")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(comment.text)
                    
                }
            }
            .listStyle(PlainListStyle())
            .refreshable{
                loadComment()
            }
            .onAppear {
                loadComment()
            }
            .navigationBarTitle("Yorumlar")
            
            HStack {
                TextField("Add a new comment...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    addComment()
                    newCommentText = ""
                    loadComment()
                    loadComment()
                }) {
                    Text("Post")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .cornerRadius(5)
                }
                .disabled(newCommentText.isEmpty)
                .padding(.trailing)
            }
            .padding(.bottom)
        }
    }
    
    
    func addComment() {
        guard let url = URL(string: "http://localhost:8080/comments") else {
            return
        }
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        let userName = defaults.string(forKey: "userName")
        let token = UserDefaults.standard.string(forKey: "tokenKey") ?? ""
        let commentData: [String: Encodable] = [
            "userId": userId,
            "text": newCommentText,
            "userName": userName,
            "postId": post.id
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: commentData, options: []) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            print("Status code: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 {
                guard let comment = try? JSONDecoder().decode(Comment.self, from: data!) else {
                    print("Decoding error")
                    return
                }
                DispatchQueue.main.async {
                    self.comments.append(comment)
                    self.commentCreated = true
                }
            } else {
                print("Invalid status code: \(httpResponse.statusCode)")
            }
        }.resume()
        newCommentText = ""
    }
    
    
    
    private func loadComment() {
        guard let url = URL(string: "http://localhost:8080/comments?postId=\(post.id)") else {
            return
        }
        print("Fetching comments from: \(url)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching comments: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            print("Raw JSON data: \(String(data: data, encoding: .utf8) ?? "Unknown data")")
            
            do {
                let decoder = JSONDecoder()
                let comments = try decoder.decode([Comment].self, from: data)
                print("Decoded comments: \(comments)")
                DispatchQueue.main.async {
                    self.comments = comments
                }
            } catch {
                print("Error decoding comments: \(error.localizedDescription)")
            }
        }.resume()
    }
}
