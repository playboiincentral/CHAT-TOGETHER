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
    @StateObject var onboardingVM = OnboardingViewModel()
    
    var body: some View {
        Group {
            if authVM.userSession != nil {
                if let user = currentUserManager.currentUser {
                    if user.gender == nil {
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
