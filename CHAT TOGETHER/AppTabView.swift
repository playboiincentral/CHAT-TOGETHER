//
//  AppTabView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/14/26.
//

import SwiftUI

struct AppTabView: View {
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: router.selectedTab == 0 ? "heart.fill" : "heart")
                    Text("Match")
                }
                .tag(0)
            RequestsView()
                .tabItem {
                    Image(systemName: router.selectedTab == 1 ? "person.badge.plus.fill" : "person.badge.plus")
                    Text("Requests")
                }
                .tag(1)
            MessagesView()
                .tabItem {
                    Image(systemName: router.selectedTab == 2 ? "message.fill" : "message")
                    Text("Chat")
                }
                .tag(2)
        }
        .tint(.primary)
    }
}
