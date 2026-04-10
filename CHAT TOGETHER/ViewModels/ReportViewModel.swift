//
//  ReportViewModel.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/17/26.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

class ReportViewModel: ObservableObject {
    
    @Published var selectedReasons: Set<ReportReason> = []
    @Published var description: String = ""
    @Published var isSubmitting = false
    @Published var isSuccess = false
    @Published var errorMessage: String?
    
    var isValid: Bool {
        !selectedReasons.isEmpty
    }
    
    func toggleReason(_ reason: ReportReason) {
        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
        }
    }
    
    func submitReport(roomId: String, reporterId: String, reportedUserId: String) {
        
        guard isValid, !isSubmitting else { return }
        
        isSubmitting = true
        
        let report = ChatReport(
            id: UUID().uuidString,
            roomId: roomId,
            reporterId: reporterId,
            reportedUserId: reportedUserId,
            reasons: Array(selectedReasons),
            description: description.isEmpty ? nil : description,
            status: .pending,
            createdAt: Timestamp()
        )
        
        do {
            try Firestore.firestore()
                .collection("reports")
                .document(report.id)
                .setData(from: report) { error in
                    
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                        } else {
                            self.isSuccess = true
                        }
                    }
                }
            
        } catch {
            isSubmitting = false
            print("❌ Encoding error:", error.localizedDescription)
        }
    }
}
