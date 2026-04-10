//
//  SettingsView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/1/26.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @EnvironmentObject private var vm: AuthViewModel
    @EnvironmentObject var currentUserManager: CurrentUserManager
    @State private var isDeleting = false
    var body: some View {
        NavigationStack {
            List {
                
                // MARK: - Appearance
                Section("Appearance") {
                    appearanceRow(.system)
                    appearanceRow(.light)
                    appearanceRow(.dark)
                }
                
                // MARK: - Legal
                Section("Legal") {
                    NavigationLink("Privacy Policy") {
                        if let url = URL(string: "https://yourapp.com/privacy") {
                            WebView(url: url)
                        }
                    }
                    
                    NavigationLink("Terms of Service") {
                        if let url = URL(string: "https://yourapp.com/terms") {
                            WebView(url: url)
                        }
                    }
                }
                
                // MARK: - Logout
                Section {
                    Button("Log Out") {
                        do {
                            try vm.signOut()
                        } catch {
                            print("Sign out error:", error.localizedDescription)
                        }
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // MARK: - Delete Account
                Section {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Text("Delete Account")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func appearanceRow(_ mode: AppearanceMode) -> some View {
        Button {
            withAnimation {
                appearanceMode = mode
            }
        } label: {
            HStack {
                Text(mode.rawValue)
                
                Spacer()
                
                if appearanceMode == mode {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
