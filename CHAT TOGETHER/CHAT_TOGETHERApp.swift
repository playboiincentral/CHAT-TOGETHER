//
//  CHAT_TOGETHERApp.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [self] granted, error in

            if granted {
                registerRemoteNotifications(application)
            }
        }
        return true
    }
    
    func registerRemoteNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    application.registerForRemoteNotifications()
                default:
                    break
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No user yet, skip saving FCM token")
            return
        }

        Firestore.firestore().collection("users").document(uid).setData([
            "fcmToken": token
        ], merge: true)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
                
        let roomId = userInfo["roomId"] as? String
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openMessagesTab,
                    object: nil,
                    userInfo: ["roomId": roomId as Any]
                )
            }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let openMessagesTab = Notification.Name("openMessagesTab")
}

@main
struct CHAT_TOGETHERApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var relationManager = RelationManager()
    @StateObject private var currentUserManager = CurrentUserManager()
    @StateObject private var friendsVM = FriendsViewModel()
    @StateObject private var warningManager = WarningManager()
    @StateObject private var router = AppRouter()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(relationManager)
                .environmentObject(currentUserManager)
                .environmentObject(friendsVM)
                .environmentObject(warningManager)
                .environmentObject(router)
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
                .onReceive(NotificationCenter.default.publisher(for: .openMessagesTab)) { notification in
                    router.selectedTab = 2
                    router.pendingRoomId = notification.userInfo?["roomId"] as? String
                }
        }
    }
}
