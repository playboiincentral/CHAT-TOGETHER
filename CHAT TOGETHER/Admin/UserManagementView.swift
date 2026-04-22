//
//  UserManagementView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI
import FirebaseFirestore

struct UserManagementView: View {
    @EnvironmentObject private var vm: AuthViewModel
    @State private var users: [AppUser] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    
    var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.fullname.lowercased().contains(searchText.lowercased()) ||
            ($0.uid?.lowercased().contains(searchText.lowercased()) ?? false) ||
            $0.email.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredUsers) { user in
                UserRowView(isLoading: $isLoading, user: user, onAction: {
                    loadUsers()
                })
            }
            .searchable(text: $searchText)
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        do {
                            try vm.signOut()
                        } catch {
                            print("Sign out error:", error.localizedDescription)
                        }
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                }
            }
            .onAppear {
                loadUsers()
            }
        }
    }
    
    func loadUsers() {
        Firestore.firestore().collection("users")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                
                guard let documents = snapshot?.documents else { return }
                
                self.users = documents.compactMap {
                    try? $0.data(as: AppUser.self)
                }
            }
    }
}
