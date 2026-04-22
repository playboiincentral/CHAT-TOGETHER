//
//  UserRowView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI
import FirebaseFunctions

struct UserRowView: View {
    @State private var showDeleteAlert = false
    @State private var showUnbanAlert = false
    @Binding var isLoading: Bool
    var user: AppUser
    var onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Text(user.fullname)
                    .font(.headline)
                
                Spacer()
                
                Text(user.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Text(user.uid ?? "No ID")
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(user.email)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                if user.status == .banned {
                    Button("Unban") {
                        showUnbanAlert = true
                    }
                    .foregroundColor(.green)
                } else {
                    Menu("Ban") {
                        Button("1 day") { banUser(days: 1) }
                        Button("7 days") { banUser(days: 7) }
                        Button("60 days") { banUser(days: 60) }
                        Button("Permanent", role: .destructive) { permanentBan() }
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Menu {
                    Button("Delete User", role: .destructive) {
                        showDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.vertical, 6)
        .confirmationDialog(
            "Delete User?",
            isPresented: $showDeleteAlert
        ) {
            Button("Delete User", role: .destructive) {
                deleteUser()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Unban User?", isPresented: $showUnbanAlert) {
            
            Button("Cancel", role: .cancel) { }
            
            Button("Unban", role: .destructive) {
                unbanUser()
            }
            
        }
    }
    
    var statusColor: Color {
        switch user.status {
        case .active:
            return .green
        case .banned:
            return .red
        case .deleted:
            return .gray
        }
    }
}

extension UserRowView {
    
    func banUser(days: Int) {
        guard let uid = user.uid else { return }
        
        isLoading = true
        
        Functions.functions(region: "asia-southeast1").httpsCallable("banUser").call([
            "userId": uid,
            "duration": days
        ]) { result, error in
            
            isLoading = false
            if let error = error {
                print("Ban error:", error)
                return
            }
            
            onAction()
        }
    }
    
    func permanentBan() {
        guard let uid = user.uid else { return }
        
        isLoading = true
        
        Functions.functions(region: "asia-southeast1").httpsCallable("banUser").call([
            "userId": uid,
            "duration": 0   // hoặc bạn xử lý 0 = permanent trong backend
        ]) { result, error in
            
            isLoading = false
            
            if let error = error {
                print("Permanent ban error:", error)
                return
            }
            
            onAction()
        }
    }
    
    func unbanUser() {
        guard let uid = user.uid else { return }
        isLoading = true
        Functions.functions(region: "asia-southeast1").httpsCallable("unbanUser").call([
            "userId": uid
        ]) { result, error in
            
            isLoading = false
            
            if let error = error {
                print("Unban error:", error)
                return
            }
            
            onAction()
        }
    }
    
    func deleteUser() {
        guard let uid = user.uid else { return }
        
        isLoading = true
        
        Functions.functions(region: "asia-southeast1").httpsCallable("deleteUser").call([
            "userId": uid
        ]) { result, error in
            
            isLoading = false
            
            if let error = error {
                print("Delete error:", error)
                return
            }
            
            onAction()
        }
    }
}
