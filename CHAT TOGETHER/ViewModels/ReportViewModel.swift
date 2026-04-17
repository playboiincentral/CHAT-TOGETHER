//
//  ReportViewModel.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/17/26.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions

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
        errorMessage = nil
        
        let functions = Functions.functions(region: "asia-southeast1")
        
        functions.httpsCallable("createReportWithSnapshot")
            .call([
                "roomId": roomId,
                "reportedUserId": reportedUserId,
                "reasons": selectedReasons.map { $0.rawValue },
                "description": description.isEmpty ? nil : description
            ]) { result, error in
                
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.isSuccess = true
                    }
                }
            }
    }
}
