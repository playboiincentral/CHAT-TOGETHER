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
    @State private var copiedReporter = false
    @State private var copiedReported = false
    
    var messages: [ReportMessage] {
        report.messages
    }
    
    var body: some View {
        VStack {
            
            // MARK: - Info
            VStack(alignment: .leading, spacing: 8) {
                Text("Reason: \(report.reasons.map{$0.rawValue}.joined(separator: ", "))")
                
                HStack {
                    Text("Reporter: \(report.reporterId)")
                    Image(systemName: "doc.on.doc")
                }
                .font(.caption)
                .onTapGesture {
                    UIPasteboard.general.string = report.reporterId
                    
                    withAnimation {
                        copiedReporter = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            copiedReporter = false
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if copiedReporter {
                        Text("Copied")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .transition(.opacity)
                    }
                }
                
                HStack {
                    Text("Reported: \(report.reportedUserId)")
                    Image(systemName: "doc.on.doc")
                }
                .font(.caption)
                .onTapGesture {
                    UIPasteboard.general.string = report.reportedUserId
                    
                    withAnimation {
                        copiedReported = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            copiedReported = false
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if copiedReported {
                        Text("Copied")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .transition(.opacity)
                    }
                }
                
                if let desc = report.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            Divider()
            
            // MARK: - Chat preview
            List(messages, id: \.createdAt) { message in
                HStack {
                    if message.senderId == report.reportedUserId {
                        Spacer()
                        Text(message.text)
                            .padding(8)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    } else {
                        Text(message.text)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
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
                
                Button("Warn") {
                    warnUser()
                }
                .foregroundStyle(.orange)
                
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
    }
}

extension ReportDetailView {
    
    func warnUser() {
        isLoading = true
        
        Functions.functions(region: "asia-southeast1")
            .httpsCallable("warnUser")
            .call([
                "userId": report.reportedUserId
            ]) { _, error in
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("Warn error:", error)
                    return
                }
                
                updateReportStatus(.resolved)
            }
    }
    
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

