//
//  AppTabView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/14/26.
//

import SwiftUI
import FirebaseAuth

struct AppTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var relationManager: RelationManager
    @EnvironmentObject private var friendsVM: FriendsViewModel
    
    var unreadCount: Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }
        
        return friendsVM.roomsWithMessage.filter {
            friendsVM.isUnread(room: $0, currentUserId: uid)
        }.count
    }
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Match")
                }
                .tag(0)
            RequestsView()
                .tabItem {
                    Image(systemName: "person.badge.plus")
                    Text("Requests")
                }
                .badge(
                    relationManager.receivedRequests.isEmpty ? nil : (relationManager.receivedRequests.count > 99 ? "99+" : "\(relationManager.receivedRequests.count)")
                )
                .tag(1)
            MessagesView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Chat")
                }
                .badge(unreadCount == 0 ? nil : (unreadCount > 99 ? "99+" : "\(unreadCount)"))
                .tag(2)
        }
        .tint(.primary)
    }
}
