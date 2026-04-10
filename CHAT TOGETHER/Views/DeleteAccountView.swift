//
//  DeleteAccountView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/3/26.
//

import SwiftUI

struct DeleteAccountView: View {
    
    @EnvironmentObject private var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isDeleting = false
    
    var body: some View {
        VStack {
            
            Spacer()
            
            // ⚠️ Warning text
            VStack(spacing: 16) {
                
                Text("Delete your account?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("This action is permanent and cannot be undone. All your data, messages, and connections will be permanently deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // 🔴 Delete button
            Button {
                Task {
                    isDeleting = true
                    await vm.deleteAccount()
                    isDeleting = false
                    dismiss()
                }
            } label: {
                Text(isDeleting ? "Deleting..." : "Delete My Account")
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
            }
            .disabled(isDeleting)
            .padding(.bottom)
        }
    }
}

#Preview {
    DeleteAccountView()
}
