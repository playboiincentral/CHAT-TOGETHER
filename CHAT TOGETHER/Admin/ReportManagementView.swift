//
//  ReportManagementView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI
import FirebaseFirestore

struct ReportManagementView: View {
    @EnvironmentObject private var vm: AuthViewModel
    @State private var reports: [ChatReport] = []
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationStack {
            List(reports) { report in
                NavigationLink {
                    ReportDetailView(report: report, isLoading: $isLoading)
                } label: {
                    ReportRowView(report: report)
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        do {
                            try vm.signOut()
                        } catch {
                            print("Sign out error:", error.localizedDescription)
                        }
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onAppear {
                loadReports()
            }
        }
    }
}

extension ReportManagementView {
    func loadReports() {
        isLoading = true
        
        Firestore.firestore().collection("reports")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Fetch error:", error.localizedDescription)
                        return
                    }
                    
                    guard let docs = snapshot?.documents else { return }
                    
                    self.reports = docs.compactMap { doc in
                        let data = doc.data()
                        
                        // 🔹 Basic fields
                        guard
                            let roomId = data["roomId"] as? String,
                            let reporterId = data["reporterId"] as? String,
                            let reportedUserId = data["reportedUserId"] as? String
                        else {
                            print("Missing required fields:", data)
                            return nil
                        }
                        
                        // 🔹 reasons: [String] → [ReportReason]
                        let reasonStrings = data["reasons"] as? [String] ?? []
                        let reasons = reasonStrings.compactMap { ReportReason(rawValue: $0) }
                        
                        // 🔹 description
                        let description = data["description"] as? String
                        
                        // 🔹 status: String → enum
                        let statusString = data["status"] as? String ?? "pending"
                        let status = ReportStatus(rawValue: statusString) ?? .pending
                        
                        // 🔹 createdAt (Timestamp giữ nguyên vì model bạn dùng Timestamp)
                        let createdAt = data["createdAt"] as? Timestamp
                        
                        // 🔹 messages
                        let rawMessages = data["messages"] as? [[String: Any]] ?? []
                        
                        let messages: [ReportMessage] = rawMessages.compactMap { msg in
                            guard
                                let senderId = msg["senderId"] as? String,
                                let text = msg["text"] as? String
                            else {
                                return nil
                            }
                            
                            let createdAt = msg["createdAt"] as? Timestamp
                            
                            return ReportMessage(
                                senderId: senderId,
                                text: text,
                                createdAt: createdAt
                            )
                        }
                        
                        return ChatReport(
                            id: doc.documentID, // ✅ FIX CHÍNH
                            roomId: roomId,
                            reporterId: reporterId,
                            reportedUserId: reportedUserId,
                            reasons: reasons,
                            description: description,
                            messages: messages,
                            status: status,
                            createdAt: createdAt
                        )
                    }
                }
            }
    }
}
