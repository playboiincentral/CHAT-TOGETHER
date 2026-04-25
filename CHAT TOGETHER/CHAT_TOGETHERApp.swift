//
//  CHAT_TOGETHERApp.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct CHAT_TOGETHERApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var relationManager = RelationManager()
    @StateObject private var currentUserManager = CurrentUserManager()
    @StateObject private var warningManager = WarningManager()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(relationManager)
                .environmentObject(currentUserManager)
                .environmentObject(warningManager)
                .preferredColorScheme(
                    appearanceMode == .dark ? .dark : .light
                )
                .animation(.easeInOut(duration: 0.2), value: appearanceMode)
                .onAppear {
                    if authVM.userSession != nil {
                        relationManager.startListening()
                        currentUserManager.startListening()
                        if let session = authVM.userSession {
                            warningManager.startListening(userId: session.uid)
                        }
                    }
                }
                .onChange(of: authVM.userSession) { session in
                    if session != nil {
                        relationManager.startListening()
                        currentUserManager.startListening()
                        if let session = authVM.userSession {
                            warningManager.startListening(userId: session.uid)
                        }
                    } else {
                        relationManager.stopListening()
                        currentUserManager.stopListening()
                        warningManager.stopListening()
                    }
                }
        }
    }
}
