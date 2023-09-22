//
//  ContentView.swift
//  1.1.1.1
//
//  Created by Melih Kılıç on 21.03.2023.
//

import SwiftUI


struct controller: View {
    @Binding var isLoggedIn: Bool
    
    
    var body: some View {
        if isLoggedIn {
            TabView {
                homeView(isLoggedIn: $isLoggedIn)
                    .tabItem{
                        Image(systemName: "house")
                        Text("Anasayfa")
                    }
                ChatRoomListView()
                    .tabItem{
                        Image(systemName: "message")
                        Text("Mesajlar")
                    }
                profileView(isLoggedIn: $isLoggedIn)
                    .tabItem{
                        Image(systemName: "person")
                        Text("Profil")
                    }
            }
        } else {
            ContentView()
                .transition(.slide)
        }
    }
}

struct controller_Previews: PreviewProvider {
    static var previews: some View {
        controller(isLoggedIn: .constant(true))
    }
}
