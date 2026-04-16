//
//  BannedView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI

struct BannedView: View {
    @EnvironmentObject private var vm: AuthViewModel
    @EnvironmentObject private var userManager: CurrentUserManager

    var body: some View {
        NavigationStack {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Account Suspended")
                .font(.title)
                .bold()
                .foregroundStyle(.primary)
            
            Text("Your account has been suspended due to violation of community guidelines.")
                .multilineTextAlignment(.center)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            if let banUntil = userManager.currentUser?.banUntil {
                Text("ban_until \(formatDate(banUntil))")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log Out") {
                    do {
                        try vm.signOut()
                    } catch {
                        print("Sign out error:", error.localizedDescription)
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(.red)
            }
        }
    }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
