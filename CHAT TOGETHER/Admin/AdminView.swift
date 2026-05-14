//
//  AdminView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI

struct AdminView: View {
    var body: some View {
        TabView {
            UserManagementView()
                .tabItem {
                    Label("Users", systemImage: "person.2")
                }
            
            ReportManagementView()
                .tabItem {
                    Label("Reports", systemImage: "exclamationmark.bubble")
                }
            
            UserStatisticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    AdminView()
}
