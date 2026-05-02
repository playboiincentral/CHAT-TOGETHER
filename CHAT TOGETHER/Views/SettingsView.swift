//
//  SettingsView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/1/26.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case light
    case dark
    
    var title: LocalizedStringKey {
        switch self {
        case .light:
            return "appearance_light"
        case .dark:
            return "appearance_dark"
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var vm: AuthViewModel
    @EnvironmentObject var currentUserManager: CurrentUserManager
    @State private var isDeleting = false
    @State private var showDeleteAccount = false
    
    var body: some View {
        NavigationStack {
            List {
                
                // MARK: - Appearance
                Section("Appearance") {
                    appearanceRow(.light)
                    appearanceRow(.dark)
                }
                
                // MARK: - Legal
                Section("Legal") {
                    NavigationLink("Privacy Policy") {
                        if let url = URL(string: "https://sites.google.com/view/chattogether-privacy") {
                            WebView(url: url)
                                .navigationBarBackButtonHidden(true)
                        }
                    }
                    
                    NavigationLink("Terms of Service") {
                        if let url = URL(string: "https://sites.google.com/view/chattogether-terms") {
                            WebView(url: url)
                                .navigationBarBackButtonHidden(true)
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
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section {
                    VStack(spacing: 8) {
                        Image("chattogether_logo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.pink)
                        
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // MARK: - Delete Account
                Section {
                    Button {
                        showDeleteAccount = true
                    } label: {
                        Text("Delete Account")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .fullScreenCover(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
        }
    }
    
    private func appearanceRow(_ mode: AppearanceMode) -> some View {
        Button {
            withAnimation {
                appearanceMode = mode
            }
        } label: {
            HStack {
                Text(mode.title)
                
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
