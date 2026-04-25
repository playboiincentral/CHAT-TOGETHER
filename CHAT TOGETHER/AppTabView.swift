//
//  AppTabView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/14/26.
//

import SwiftUI

struct AppTabView: View {
    @State private var selectedTab: Int = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "heart.fill" : "heart")
                    Text("Match")
                }
                .tag(0)
            RequestsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.badge.plus.fill" : "person.badge.plus")
                    Text("Requests")
                }
                .tag(1)
            MessagesView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "message.fill" : "message")
                    Text("Chat")
                }
                .tag(2)
        }
        .tint(.primary)
    }
}
