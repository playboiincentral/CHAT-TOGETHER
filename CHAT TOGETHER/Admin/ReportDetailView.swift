//
//  ReportDetailView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFunctions

struct ReportDetailView: View {
    var report: ChatReport
    @Binding var isLoading: Bool
    
    @State private var messages: [Message] = []
    
    var body: some View {
        VStack {
            
            // MARK: - Info
            VStack(alignment: .leading, spacing: 8) {
                Text("Reason: \(report.reasons.map{$0.rawValue}.joined(separator: ", "))")
                
                Text("Reported User: \(report.reportedUserId)")
                    .font(.caption)
                
                if let desc = report.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            Divider()
            
            // MARK: - Chat preview
            List(messages) { message in
                HStack {
                    if message.senderId == report.reportedUserId {
                        Text(message.text)
                            .foregroundColor(.red)
                    } else {
                        Text(message.text)
                    }
                }
            }
            
            // MARK: - Actions
            HStack {
                Button("Ignore") {
                    updateReportStatus(.rejected)
                }
                .foregroundColor(.gray)
                
                Spacer()
                
                Menu("Ban") {
                    Button("1 days") {
                        banUser(days: 1)
                    }
                    Button("7 days") {
                        banUser(days: 7)
                    }
                    Button("60 days") {
                        banUser(days: 60)
                    }
                    Button("Permanent", role: .destructive) {
                        permanentBan()
                    }
                }
                .foregroundColor(.red)
            }
            .padding()
        }
        .navigationTitle("Report Detail")
        .onAppear {
            loadMessages()
        }
    }
}

extension ReportDetailView {
    func loadMessages() {
        Firestore.firestore().collection("messages")
            .whereField("roomId", isEqualTo: report.roomId)
            .order(by: "createdAt")
            .limit(toLast: 50)
            .getDocuments { snapshot, _ in
                
                guard let docs = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.messages = docs.compactMap { doc in
                        let data = doc.data()

                        return Message(
                            id: doc.documentID,
                            senderId: data["senderId"] as? String ?? "",
                            text: data["text"] as? String ?? "",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                            reaction: data["reaction"] as? String,
                            isAI: data["isAI"] as? Bool ?? false,
                            roomId: data["roomId"] as? String ?? ""
                        )
                    }
                }
            }
    }
}

extension ReportDetailView {
    
    func banUser(days: Int) {
        isLoading = true

        Functions.functions(region: "asia-southeast1").httpsCallable("banUser").call([
            "userId": report.reportedUserId,
            "duration": days
        ]) { _, error in
            
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("Ban error:", error)
                return
            }

            updateReportStatus(.resolved)
        }
    }
    
    func permanentBan() {
        isLoading = true

        Functions.functions(region: "asia-southeast1").httpsCallable("banUser").call([
            "userId": report.reportedUserId,
            "duration": 0   // backend hiểu 0 = permanent
        ]) { _, error in
            
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("Permanent ban error:", error)
                return
            }

            updateReportStatus(.resolved)
        }
    }
    
    func updateReportStatus(_ status: ReportStatus) {
        Firestore.firestore().collection("reports")
            .document(report.id)
            .updateData([
                "status": status.rawValue
            ])
    }
}

