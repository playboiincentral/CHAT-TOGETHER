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
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(relationManager)
                .environmentObject(currentUserManager)
                .preferredColorScheme(
                    appearanceMode == .dark ? .dark :
                        appearanceMode == .light ? .light : nil
                )
                .onAppear {
                    if authVM.userSession != nil {
                        relationManager.startListening()
                        currentUserManager.startListening()
                    }
                }
                .onChange(of: authVM.userSession) { session in
                    if session != nil {
                        relationManager.startListening()
                        currentUserManager.startListening()
                    } else {
                        relationManager.stopListening()
                        currentUserManager.stopListening()
                    }
                }
                .onChange(of: appearanceMode) { mode in
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first else { return }
                    
                    switch mode {
                    case .system:
                        window.overrideUserInterfaceStyle = .unspecified
                    case .light:
                        window.overrideUserInterfaceStyle = .light
                    case .dark:
                        window.overrideUserInterfaceStyle = .dark
                    }
                }
        }
    }
}
