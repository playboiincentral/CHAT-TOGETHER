//
//  WaitingView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/23/26.
//

import SwiftUI

struct WaitingView: View {
    @Environment(\.dismiss) var dismiss

    let currentUserAvatar: String?
    let partnerAvatar: String?
    
    var body: some View {
        VStack(spacing: 30) {
            
            Spacer()
            
            Text("Connecting...")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 30) {
                
                // 👤 Current User
                avatarView(url: currentUserAvatar)
                
                // 🔄 Loading
                ProgressView()
                    .scaleEffect(1.5)
                
                // 👤 Partner
                avatarView(url: partnerAvatar)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                dismiss()
            }
        }
    }
    
    // MARK: - Avatar
    @ViewBuilder
    private func avatarView(url: String?) -> some View {
        if let url = url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
        }
    }
}
