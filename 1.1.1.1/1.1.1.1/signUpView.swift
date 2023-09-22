//
//  signUpView.swift
//  1.1.1.1
//
//  Created by Melih Kılıç on 13.05.2023.
//
import SwiftUI

struct signUpView: View {
    @State private var name = ""
    @State private var surname = ""
    @State private var userName = ""
    @State private var email = ""
    @State private var password = ""

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Ad")) {
                        TextField("Adınızı girin", text: $name)
                    }
                    Section(header: Text("Soyad")) {
                        TextField("Soyadınızı girin", text: $surname)
                    }
                    Section(header: Text("Kullanıcı Adı")) {
                        TextField("Kullanıcı adınızı girin", text: $userName)
                    }
                    Section(header: Text("Email")) {
                        TextField("Emailinizi girin", text: $email)
                            .keyboardType(.emailAddress)
                    }
                    Section(header: Text("Parola")) {
                        SecureField("Parolanızı girin", text: $password)
                    }
                }
                Button(action: {
                    saveNewUser()
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Kayıt Ol")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Kayıt Ol")
        }
    }

    func saveNewUser() {
        let url = URL(string: "http://localhost:8080/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = [            "name": name,            "surname": surname,            "email": email,            "userName": userName,            "password": password        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "Unknown error")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let accessToken = json["accessToken"] as? String, let refreshToken = json["refreshToken"] as? String, let userId = json["userId"] as? String {
                            UserDefaults.standard.set(accessToken, forKey: "tokenKey")
                            UserDefaults.standard.set(refreshToken, forKey: "refreshKey")
                            UserDefaults.standard.set(userId, forKey: "currentUser")
                            UserDefaults.standard.set(userName, forKey: "userName")
                            UserDefaults.standard.set(name, forKey: "name")
                        }
                    }
                }
            }
        }.resume()
    }
}

struct signUpView_Previews: PreviewProvider {
    static var previews: some View {
        signUpView()
    }
}
