import SwiftUI
import UIKit


struct profileView: View {
    let defaults = UserDefaults.standard
    @State private var isEditUserViewActive = false
    @State private var isEditProfilePhotoViewActive = false
    
    var userName: String {
            return defaults.string(forKey: "userName") ?? ""
        }
        
        var userId: Int {
            return defaults.integer(forKey: "currentUser")
        }
    
    @State var posts: [Post] = []
    @Binding var isLoggedIn: Bool
    @State private var profilePicture: Image?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        if isLoggedIn {
            NavigationView {
                VStack {
                    HStack {
                        Button(action: {
                               isEditProfilePhotoViewActive = true
                           }) {
                               if let profilePicture = profilePicture {
                                   profilePicture
                                       .resizable()
                                       .aspectRatio(contentMode: .fill)
                                       .frame(width: 100, height: 100)
                                       .clipShape(Circle())
                                       .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                       .shadow(radius: 10)
                               } else {
                                   Image(systemName: "person.crop.circle.fill")
                                       .resizable()
                                       .frame(width: 100, height: 100)
                                       .clipShape(Circle())
                                       .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                       .shadow(radius: 10)
                               }
                           }
                           .buttonStyle(PlainButtonStyle()) // Remove default button styling
                           .sheet(isPresented: $isEditProfilePhotoViewActive) {
                               ZStack {
                                   Color(.systemGray6)
                                   editProfilePhotoView()
                                       .presentationDragIndicator(.visible)
                                       .edgesIgnoringSafeArea(.all)
                               }
                           }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text(userName)
                                .font(.title)
                            Text(String(userId))
                                .font(.subheadline)
                        }
                        Spacer()
                        Button(action: {
                            isEditUserViewActive = true
                        }) {
                            Image(systemName: "ellipsis")
                        }
                        .sheet(isPresented: $isEditUserViewActive) {
                            ZStack {
                                Color(.systemGray6)
                                editUserView()
                                    .presentationDragIndicator(.visible)
                                    .edgesIgnoringSafeArea(.all)
                            }
                        }
                        Spacer()
                    }
                    .padding([.top, .leading], 20)

                    Divider()
                    List(posts.filter { $0.userId == getCurrentUserId() }.reversed()) { post in
                        VStack(alignment: .leading) {
                            VStack(alignment: .leading) {
                                Text(post.title)
                                    .font(.headline)
                                if let imageData = post.imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .clipped()
                                }
                                Text(post.text)
                                    .font(.subheadline)
                                NavigationLink(destination: CommentView(post: post)) {
                                    Text("Yorumları Görüntüle")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Button(action: {
                            self.showingDeleteAlert = true
                        }) {
                            Text("Gönderiyi Sil")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .actionSheet(isPresented: $showingDeleteAlert) {
                            ActionSheet(title: Text("Gönderiyi silmek istediğinizden emin misiniz?"), buttons: [
                                .destructive(Text("Evet")) {
                                    deletePost(postId: Int(post.id))
                                    fetchUserPosts { [self] posts in
                                                    DispatchQueue.main.async {
                                                        self.posts = posts
                                                    }
                                                }
                                },
                                .cancel()
                            ])
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {fetchUserPosts { [self] posts in
                        DispatchQueue.main.async {
                            self.posts = posts
                        }
                    }
                        
                    }
                    .navigationBarTitle("Profil", displayMode: .inline)
                    .navigationBarItems(leading:
                                            Button(action: {
                        clearUserDefaults()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    )
                    .navigationBarItems(trailing:
                                            NavigationLink(destination: postCreateView(postCreatedHandler: handlePostCreated)) {         //profileEditView ekle
                        Image(systemName: "square.and.arrow.up")
                    }
                    )
                }
                .onAppear {
                    fetchUserPosts { [self] posts in
                        DispatchQueue.main.async {
                        self.posts = posts
                    }
                    }
                        let defaults = UserDefaults.standard
                    
                    fetchBlobImage()
                }
            }
        } else {
                    ContentView()
                        .transition(.slide)
        }
    }
    
    func loadData() {
        // Make a GET request to the feed endpoint and decode the response
        let url = URL(string: "http://localhost:8080/posts")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedPosts = try? decoder.decode([Post].self, from: data) {
                    DispatchQueue.main.async {
                        // Update the UI with the loaded posts
                        self.posts = decodedPosts
                    }
                    return
                }
            }
            // Handle any errors that occurred during the request or decoding
            print("Error loading feed data")
        }.resume()
    }
    
    func handlePostCreated() {
        loadData()
    }
    
    func deletePost(postId: Int) {
        guard let url = URL(string: "http://localhost:8080/posts/\(postId)") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        let token = defaults.string(forKey: "tokenKey") ?? ""
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(token, forHTTPHeaderField: "Authorization")
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("An error occurred while deleting the post: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("An error occurred while deleting the post. HTTP status code: \(httpResponse.statusCode)")
                return
            }
            
            DispatchQueue.main.async {
                if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                    self.posts.remove(at: index)
                }
            }
        }.resume()
    }

    
    func fetchBlobImage() {
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        let token = defaults.string(forKey: "tokenKey") ?? ""
        
        guard let url = URL(string: "http://localhost:8080/photos?userId=\(userId)") else {
            print("Profil Fotoğrafı Alınamadı: Geçersiz URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Profil Fotoğrafı Alınamadı:", error)
                    return
                }

                guard let data = data else {
                    print("Profil Fotoğrafı Alınamadı: Boş veri.")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let id = json["id"] as? Int,
                       let imageString = json["image"] as? String,
                       let imageData = Data(base64Encoded: imageString),
                       let uiImage = UIImage(data: imageData)
                    {
                        let image = Image(uiImage: uiImage)
                        DispatchQueue.main.async {
                            profilePicture = image
                        }
                        print("Profil Fotoğrafı Başarıyla Alındı")
                        print("ID: \(id)")
                    } else {
                        print("Profil Fotoğrafı Alınamadı: Geçersiz JSON verisi.")
                    }
                } catch {
                    print("Profil Fotoğrafı Alınamadı: JSON dönüştürme hatası -", error)
                }
            }.resume()
    }

    
    func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("UserDefaults cleared")
        isLoggedIn = false
    }

    
    func isPostLiked(_ post: Post) -> Bool {
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            return posts[index].postLikes.contains(where: { $0.userId == userId })
        }
        
        return false
    }
    
    func getCurrentUserId() -> Int {
            return defaults.integer(forKey: "currentUser")
        }
    
    func fetchUserPosts(completion: @escaping ([Post]) -> Void) {
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        let token = defaults.string(forKey: "tokenKey") ?? ""

        guard let url = URL(string: "http://localhost:8080/posts?userId=\(userId)") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                completion([])
                return
            }

            guard let data = data else {
                completion([])
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let posts = try decoder.decode([Post].self, from: data)
                completion(posts)
            } catch {
                print("Error decoding posts: \(error)")
                completion([])
            }
        }.resume()
    }

}



struct editProfilePhotoView: View {
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    
    var body: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            }
            
            Button(action: {
                isShowingImagePicker = true
            }) {
                Text("Fotoğraf Seç")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
            
            Button(action: {
                uploadPhoto()
            }) {
                Text("Yükle")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(10)
            }
            .padding()
        }
        .sheet(isPresented: $isShowingImagePicker, onDismiss: loadImage) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    func loadImage() {
        guard let selectedImage = selectedImage else { return }
        // Do any necessary image processing here
    }
    
    func uploadPhoto() {
        guard let selectedImage = selectedImage,
              let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let defaults = UserDefaults.standard
        let userId = defaults.integer(forKey: "currentUser")
        let token = defaults.string(forKey: "tokenKey") ?? ""
        
        let url = URL(string: "http://localhost:8080/photos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        let contentType = "multipart/form-data; boundary=\(boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"imageFile\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("Profil Fotoğrafı Başarıyla Kaydedildi")
                    isShowingImagePicker = false
                } else {
                    print("Profil Fotoğrafı Kaydedilirken Bir Hata Oluştu")
                }
        }.resume()
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = context.coordinator
        imagePicker.allowsEditing = true // Kullanıcının kırpma işlemini yapabilmesi için bu özelliği etkinleştiriyoruz
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage { // Kırpılmış fotoğrafı alıyoruz
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage { // Kullanıcı kırpma yapmadıysa orijinal fotoğrafı alıyoruz
                parent.image = originalImage
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}




struct editUserView: View {
    @State private var name = ""
    @State private var surname = ""
    @State private var userName = ""
    @State private var email = ""
    @State private var isEditUserViewActive = true
    
    let defaults = UserDefaults.standard
    let userId: Int
    
    init() {
        self.userId = defaults.integer(forKey: "currentUser")
    }
    
    var body: some View {
        VStack(spacing: 35) {
            Text("Bilgilerini Güncelle")
                .padding()
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Section {
                TextField("İsminizi girin", text: $name)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15.0)
                    .shadow(radius: 5.0)
                    .frame(height: 50)
            }
            Section {
                TextField("Soyisminizi girin", text: $surname)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15.0)
                    .shadow(radius: 5.0)
                    .frame(height: 50)
            }
            Section {
                TextField("Kullanıcı adınızı girin", text: $userName)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15.0)
                    .shadow(radius: 5.0)
                    .frame(height: 50)
            }
            Section {
                TextField("Email adresinizi girin", text: $email)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15.0)
                    .shadow(radius: 5.0)
                    .keyboardType(.emailAddress)
                    .frame(height: 50)
            }
            Button(action: {
                updateUser()
            }) {
                Text("Kaydet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 50)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }

        .padding()
        .onDisappear {
            isEditUserViewActive = false
        }
    }
    
    func updateUser() {
        
        UserDefaults.standard.set(userName, forKey: "userName")
        
        let token = defaults.string(forKey: "tokenKey") ?? ""
        
        print("userId: \(userId)")
        
        guard let url = URL(string: "http://localhost:8080/users/\(userId)") else {
            print("Geçersiz URL.")
            return
        }
        
        let updatedUserData: [String: Any] = [
            "name": name,
            "surname": surname,
            "userName": userName,
            "email": email
        ]
                print("username: \(userName)")
                
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updatedUserData)
        } catch {
            print("Veri dönüştürme hatası: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("İstek hatası: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    isEditUserViewActive = false
                } else {
                    print("İstek başarısız. Dönüş kodu: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}


struct profileView_Previews: PreviewProvider {
    static var previews: some View {
        controller(isLoggedIn: .constant(true))
    }
}
