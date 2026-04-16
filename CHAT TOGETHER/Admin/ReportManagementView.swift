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
                        Text("Logout")
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
        Firestore.firestore().collection("reports")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, _ in
                
                guard let docs = snapshot?.documents else { return }
                
                self.reports = docs.compactMap {
                    try? $0.data(as: ChatReport.self)
                }
            }
    }
}
