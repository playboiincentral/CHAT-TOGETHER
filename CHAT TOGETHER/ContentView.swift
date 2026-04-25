//
//  ContentView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var currentUserManager: CurrentUserManager
    @EnvironmentObject var warningManager: WarningManager
    @StateObject var onboardingVM = OnboardingViewModel()
    
    var body: some View {
        ZStack {
            mainContent
            
            if warningManager.showWarning {
                
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        
                        Text("⚠️ Warning")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        
                        Text(warningManager.message)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        
                        Button("I understand and I won't do it again.") {
                            warningManager.markAsSeen()
                        }
                        .padding()
                        .background(Color.red)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .padding()
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }
                .transition(.opacity)
            }
        }
    }
    
    var mainContent: some View {
        Group {
            if authVM.userSession != nil {
                if let user = currentUserManager.currentUser {
                    
                    if user.status == .banned {
                        BannedView()
                            .environmentObject(currentUserManager)
                    }
                    
                    else if user.isAdmin {
                        AdminView()
                    }
                    
                    else if user.gender == nil {
                        // Show onboarding cho user mới
                        OnboardingView()
                            .environmentObject(onboardingVM)
                            .environmentObject(currentUserManager)
                    } else {
                        // User đã hoàn tất onboarding → show main tab
                        AppTabView()
                            .environmentObject(currentUserManager)
                    }
                } else {
                    // Đang load user từ Firestore
                    ProgressView("Loading user...")
                }
            } else {
                // Chưa login → show login
                LoginView()
            }
        }
    }
}
