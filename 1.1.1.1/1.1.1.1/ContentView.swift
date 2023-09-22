//
//  ContentView.swift
//  1.1.1.1
//
//  Created by Melih Kılıç on 21.03.2023.
//

import SwiftUI

struct ContentView: View {

    @State private var userName = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var isLoggedIn = false
    
    
    
    var body: some View {
        if isLoggedIn {
                controller(isLoggedIn: $isLoggedIn)
                    .transition(.slide) // İstediğiniz geçiş efektini ekleyebilirsiniz
        } else {
            NavigationView{
                VStack {
                    Spacer(minLength: 30)
                    Text("SHARE CIRCLE")
                        .font(.title)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 30)
                    Image("logo1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(.bottom, 50)
                    VStack(spacing: 20) {
                        HStack {
                            Spacer()
                            TextField("Kullanıcı Adı", text: $userName)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(15.0)
                                .shadow(radius: 5.0)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        HStack {
                            Spacer()
                            SecureField("Parola", text: $password)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(15.0)
                                .shadow(radius: 5.0)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        Button(action: {
                            login()
                        }) {
                            Text("Giriş Yap")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                            
                        }.disabled(isLoading)
                        
                        .padding()
                        Spacer()
                        HStack {
                            Text("Hesabın yok mu?")
                            NavigationLink(destination: signUpView()) {
                                Text("Kayıt Ol")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                }
            }
            .onAppear{
                if let currentUser = UserDefaults.standard.string(forKey: "currentUser") {
                    print("currentUser:", currentUser)
                }
                if let userName = UserDefaults.standard.string(forKey: "userName") {
                    print("userName:", userName)
                }
            }
        }
    }
   
    func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("UserDefaults cleared")
    }

        
    func login() {
        print("Login button pressed")

        let url = URL(string: "http://localhost:8080/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "userName": userName,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let accessToken = json["accessToken"] as? String
                    let refreshToken = json["refreshToken"] as? String
                    let userId = json["userId"] as? Int64
                    
                    UserDefaults.standard.set(accessToken, forKey: "tokenKey")
                    UserDefaults.standard.set(refreshToken, forKey: "refreshKey")
                    UserDefaults.standard.set(Int64(bitPattern: UInt64(userId ?? 0)), forKey: "currentUser")
                    UserDefaults.standard.set(userName, forKey: "userName")
                    print(UserDefaults.standard.dictionaryRepresentation())
                    if let currentUser = UserDefaults.standard.string(forKey: "currentUser") {
                        print("currentUser: \(currentUser)")
                    } else {
                        print("currentUser bilgisi bulunamadı.")
                    }


                    
                    print("Login successful") 
                    isLoggedIn = true
                } else {
                    // Handle failed login case
                    print("Login failed")
                }
            }
            else {
                print("Login failed") // Print failure message
            }
            
            // Reset the fields
            userName = ""
            password = ""
        }.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
