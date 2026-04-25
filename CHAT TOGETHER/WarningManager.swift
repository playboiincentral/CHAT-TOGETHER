//
//  WarningManager.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/26/26.
//

import Foundation
import FirebaseFirestore

class WarningManager: ObservableObject {
    
    @Published var showWarning: Bool = false
    @Published var message: String = ""
    
    private var listener: ListenerRegistration?
    private var currentWarnings: Int = 0
    private var lastSeenWarnings: Int = 0
    private var userId: String?
    
    func startListening(userId: String) {
        self.userId = userId
        listener?.remove()
        
        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .addSnapshotListener { snapshot, error in
                
                guard let data = snapshot?.data() else { return }
                
                let warnings = (data["warnings"] as? NSNumber)?.intValue ?? 0
                let lastSeen = (data["lastSeenWarning"] as? NSNumber)?.intValue ?? 0
                self.currentWarnings = warnings
                self.lastSeenWarnings = lastSeen
                
                if warnings > lastSeen {
                    self.message = "You have violated our Terms of Service. We have taken action on this content. Repeated violations may result in account suspension or permanent ban. Please do not repeat this behavior."
                    self.showWarning = true
                }
            }
    }
    
    func markAsSeen() {
        guard let userId else { return }
        
        showWarning = false
        
        // ✅ update lên server
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .updateData([
                "lastSeenWarning": currentWarnings
            ])
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        showWarning = false
        currentWarnings = 0
        lastSeenWarnings = 0
        userId = nil
    }
}
