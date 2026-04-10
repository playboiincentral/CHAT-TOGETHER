//
//  HomeView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import SwiftUI

struct HomeView: View {
    
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var currentUser: CurrentUserManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                ZStack {
                    
                    Text("chat together")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        NavigationLink {
                            if let user = currentUser.currentUser {
                                    ProfileView(user: user, isCurrentUser: true)
                                }
                        } label: {
                                avatarView
                            }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 145)
                
                Text(viewModel.isMatching ? "Looking for someone..." : "Ready to meet someone?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                if viewModel.isMatching {
                    Text(timeString(from: viewModel.elapsedSeconds))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(.pink)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Button {
                    if viewModel.isMatching {
                        viewModel.stopMatching()
                    } else {
                        viewModel.startMatching()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isMatching ? "xmark.circle.fill" : "heart.fill")
                        Text(viewModel.isMatching ? "Stop Matching" : "Start Matching")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: viewModel.isMatching
                            ? [.gray, .gray]
                            : [.pink, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(
                        color: viewModel.isMatching
                        ? .black.opacity(0.3)
                        : .pink.opacity(0.4),
                        radius: 10,
                        y: 5
                    )
                    .scaleEffect(viewModel.isMatching ? 1.05 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6),
                               value: viewModel.isMatching)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .fullScreenCover(item: $viewModel.currentRoom) { room in
                ChatView(room: room)
            }
            .onChange(of: viewModel.currentRoom != nil) { isPresented in
                if !isPresented {
                    viewModel.resetAfterChat()
                }
            }
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatar = currentUser.currentUser?.avatar,
           let url = URL(string: avatar) {
            
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
                    .controlSize(.small)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
        } else {
            
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
