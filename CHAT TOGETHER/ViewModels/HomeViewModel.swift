//
//  HomeViewModel.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@MainActor
class HomeViewModel: ObservableObject {
    
    @Published var currentRoom: ChatRoom?
    @Published var isMatching = false
    @Published var elapsedSeconds = 0
    @Published var isCheckingRoom = true
    
    private var listener: ListenerRegistration?
    private var timer: Timer?
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "asia-southeast1")
    var userId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    deinit {
        listener?.remove()
        timer?.invalidate()
    }
    
    // MARK: - Start Matching
    func startMatching() {
        guard !userId.isEmpty else { return }
        guard !isMatching else { return }
        
        // 🔥 BLOCK khi đang check reconnect
        guard !isCheckingRoom else { return }
        
        // 🔥 BLOCK nếu đã có room
        guard currentRoom == nil else { return }
        
        cleanup()
        
        elapsedSeconds = 0
        isMatching = true
        
        startTimer()
        listenForRoom()
        joinQueue()
    }
    
    // MARK: - Stop Matching
    func stopMatching() {
        cleanup()
        leaveQueue()
    }
    
    func resetAfterChat() {
        stopTimer()
        elapsedSeconds = 0
        isMatching = false
        currentRoom = nil
    }
    
    // MARK: - Cleanup
    private func cleanup() {
        stopTimer()
        listener?.remove()
        listener = nil
        isMatching = false
    }
    
    // MARK: - Cloud Function: Join Queue
    private func joinQueue() {
        functions.httpsCallable("joinQueue").call { result, error in
            if let error = error {
                print("joinQueue error:", error)
            }
        }
    }
    
    // MARK: - Cloud Function: Leave Queue
    private func leaveQueue() {
        functions.httpsCallable("leaveQueue").call { result, error in
            if let error = error {
                print("leaveQueue error:", error)
            }
        }
    }
    
    // MARK: - Listen for Room
    private func listenForRoom() {
        
        listener?.remove()
        
        listener = db.collection("chatRooms")
            .whereField("users", arrayContains: userId)
            .whereField("status", isEqualTo: "active")
            .whereField("type", isEqualTo: "random")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                
                guard let self = self else { return }
                guard self.currentRoom == nil else { return }
                guard let document = snapshot?.documents.first else { return }
                
                let data = document.data()
                
                let room = ChatRoom(
                    id: document.documentID,
                    users: data["users"] as? [String] ?? [],
                    type: ChatRoomType(rawValue: data["type"] as? String ?? "") ?? .random,
                    activeUsers: data["activeUsers"] as? [String] ?? [],
                    status: RoomStatus(rawValue: data["status"] as? String ?? "") ?? .active,
                    createdAt: data["createdAt"] as? Timestamp,
                    endedAt: data["endedAt"] as? Timestamp,
                    endedBy: data["endedBy"] as? String,
                    lastActivityAt: data["lastActivityAt"] as? Timestamp
                )
                
                DispatchQueue.main.async {
                    self.stopTimer()
                    self.isMatching = false
                    self.currentRoom = room
                }
            }
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func checkExistingRoom() {
        guard !userId.isEmpty else {
            isCheckingRoom = false
            return
        }
        
        db.collection("chatRooms")
            .whereField("users", arrayContains: userId)
            .whereField("status", isEqualTo: "active")
            .whereField("type", isEqualTo: "random")
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, _ in
                
                guard let self = self else { return }
                defer {
                    DispatchQueue.main.async {
                        self.isCheckingRoom = false
                    }
                }
                guard let document = snapshot?.documents.first else { return }
                
                let data = document.data()
                
                let room = ChatRoom(
                    id: document.documentID,
                    users: data["users"] as? [String] ?? [],
                    type: ChatRoomType(rawValue: data["type"] as? String ?? "") ?? .random,
                    activeUsers: data["activeUsers"] as? [String] ?? [],
                    status: RoomStatus(rawValue: data["status"] as? String ?? "") ?? .active,
                    createdAt: data["createdAt"] as? Timestamp,
                    endedAt: data["endedAt"] as? Timestamp,
                    endedBy: data["endedBy"] as? String,
                    lastActivityAt: data["lastActivityAt"] as? Timestamp
                )
                
                DispatchQueue.main.async {
                    self.currentRoom = room
                    self.isMatching = false
                }
            }
    }
}
