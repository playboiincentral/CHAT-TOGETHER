import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

class ChatViewModel: ObservableObject {
    
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var shouldDismiss = false
    @Published var showPartnerLeftAlert = false
    @Published var partner: AppUser?
    @Published var showUnfriendAlert = false
    private var friendshipListener: ListenerRegistration?
    private var partnerListener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    @Published var room: ChatRoom
    private var heartbeatTimer: Timer?
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var roomListener: ListenerRegistration?
    
    init(room: ChatRoom) {
        self.room = room
        fetchPartner()
        listenMessages()
        listenRoomStatus()
        
        if room.type == .random {
            startHeartbeat()
        }
        
        listenFriendship()
    }
    
    deinit {
        if room.type == .random {
            stopHeartbeat()
        }
        
        listener?.remove()
        roomListener?.remove()
        partnerListener?.remove()
        friendshipListener?.remove()
    }
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private var isRoomActive = true
    
    private func sendHeartbeat() {
        guard isRoomActive else { return }
        
        db.collection("chatRooms")
            .document(room.roomId)
            .updateData([
                "lastActivityAt": FieldValue.serverTimestamp()
            ])
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    // MARK: - Fetch partner name
    func fetchPartner() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        guard let partnerId = room.users.first(where: { $0 != currentUid }) else {
            print("No partner found")
            return
        }
        
        partnerListener = db.collection("users")
            .document(partnerId)
            .addSnapshotListener { [weak self] snapshot, error in
                
                guard let self = self else { return }
                
                if let error = error {
                    print("Fetch partner error:", error.localizedDescription)
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    print("User not found")
                    return
                }
                
                do {
                    let user = try snapshot.data(as: AppUser.self)
                    
                    DispatchQueue.main.async {
                        self.partner = user
                    }
                    
                } catch {
                    print("Decode error:", error)
                }
            }
    }
    
    // MARK: - Listen messages
    private func listenMessages() {
        listener = db.collection("chatRooms")
            .document(room.roomId)
            .collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, _ in
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                self.messages = documents.map { doc in
                    
                    let timestamp = doc["createdAt"] as? Timestamp
                    let isAI = doc["isAI"] as? Bool ?? false
                    return Message(
                        id: doc.documentID,
                        senderId: doc["senderId"] as? String ?? "",
                        text: doc["text"] as? String ?? "",
                        createdAt: timestamp?.dateValue(),
                        reaction: doc["reaction"] as? String,
                        isAI: isAI
                    )
                }
            }
            }
    }
    
    private func listenRoomStatus() {
        
        roomListener = db.collection("chatRooms")
            .document(room.roomId)
            .addSnapshotListener { [weak self] snapshot, _ in
                
                guard let self = self else { return }
                
                // 🔥 1. ROOM BỊ XOÁ
                if snapshot == nil || snapshot?.exists == false {
                    
                    guard self.isRoomActive else { return }
                    
                    DispatchQueue.main.async {
                        self.isRoomActive = false
                        self.stopHeartbeat()
                        
                        // ❗ HIỆN ALERT
                        self.showPartnerLeftAlert = true
                        
                        // ❗ cleanup nhưng KHÔNG dismiss
                        self.cleanupAfterBlock()
                    }
                    
                    return
                }
                
                // 🔥 2. NORMAL FLOW
                guard let data = snapshot?.data() else { return }
                
                do {
                    let updatedRoom = try snapshot!.data(as: ChatRoom.self)
                    DispatchQueue.main.async {
                        self.room = updatedRoom
                    }
                } catch {
                    print("Decode room error:", error)
                }
                
                let status = data["status"] as? String ?? ""
                let endedBy = data["endedBy"] as? String
                
                if status == "ended" {
                    
                    guard self.isRoomActive else { return }
                    
                    DispatchQueue.main.async {
                        self.isRoomActive = false
                        self.stopHeartbeat()
                        
                        if endedBy == "timeout" {
                            self.showPartnerLeftAlert = true
                        } else if endedBy != self.userId {
                            self.showPartnerLeftAlert = true
                        } else {
                            self.shouldDismiss = true
                        }
                        
                        self.cleanupAfterBlock()
                    }
                }
            }
    }
    
    // MARK: - Send message

    func sendMessage() {
        guard let currentUserId = userId else { return }
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isRoomActive else { return }
        
        let isAI = trimmed.range(of: "@togi", options: .caseInsensitive) != nil
        
        messageText = ""
        
        let roomRef = db.collection("chatRooms").document(room.roomId)
        let messageRef = roomRef.collection("messages").document()
        
        let batch = db.batch()
        
        batch.setData([
            "senderId": currentUserId,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp(),
            "reaction": NSNull(),
            "isAITrigger": isAI
        ], forDocument: messageRef)
        
        var updateData: [String: Any] = [
            "lastActivityAt": FieldValue.serverTimestamp()
        ]
        
        if room.type == .friend {
            updateData["lastMessage"] = trimmed
            updateData["lastMessageSenderId"] = currentUserId
            updateData["lastMessageAt"] = FieldValue.serverTimestamp()
        }
        
        batch.updateData(updateData, forDocument: roomRef)
        
        batch.commit()
    }
    
    // MARK: - Leave room
    func leaveRoom() {
        let roomId = room.roomId
        guard !roomId.isEmpty else { return }
        
        stopHeartbeat()
        
        let data: [String: Any] = [
            "roomId": roomId
        ]
        
        Functions.functions(region: "asia-southeast1")
            .httpsCallable("leaveRoom")
            .call(data) { [weak self] _, error in
                
                if let error = error {
                    print("Leave error:", error.localizedDescription)
                    return
                }
                
                DispatchQueue.main.async {
                    self?.shouldDismiss = true
                }
            }
    }
    
    // MARK: - Update reaction
    func updateReaction(
        messageId: String,
        senderId: String,
        reaction: String
    ) {
        guard senderId != userId else { return }
        
        db.collection("chatRooms")
            .document(room.roomId)
            .collection("messages")
            .document(messageId)
            .updateData([
                "reaction": reaction
            ])
    }
    
    func removeReaction(messageId: String) {
        db.collection("chatRooms")
            .document(room.roomId)
            .collection("messages")
            .document(messageId)
            .updateData([
                "reaction": FieldValue.delete()
            ])
    }
    
    func markAsRead() {
        guard let userId = userId else { return }
        
        db.collection("chatRooms")
            .document(room.roomId)
            .updateData([
                "lastReadAt.\(userId)": Timestamp(date: Date())
            ])
    }
    
    func handleOnAppear() {
        if room.type == .friend {
            markAsRead()
        }
        
        if room.type == .random {
               sendHeartbeat()
           }
    }
    
    func listenFriendship() {
        guard room.type == .friend else { return }
        guard let currentUserId = userId else { return }
        
        let partnerId = room.users.first { $0 != currentUserId }
        guard let partnerId = partnerId else { return }
        
        let sorted = [currentUserId, partnerId].sorted()
        let friendshipId = sorted.joined(separator: "_")
        
        let ref = db.collection("friendships").document(friendshipId)
        
        friendshipListener = ref.addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self else { return }
            
            // ❌ doc bị xoá = unfriend
            if snapshot == nil || snapshot?.exists == false {
                
                DispatchQueue.main.async {
                    self.showUnfriendAlert = true
                    
                    // 🔥 cleanup để tránh bug
                    self.listener?.remove()
                    self.listener = nil
                    
                    self.roomListener?.remove()
                    self.roomListener = nil
                    
                    self.partnerListener?.remove()
                    self.partnerListener = nil
                    
                    self.friendshipListener?.remove()
                    self.friendshipListener = nil
                }
            }
        }
    }
    
    func cleanupAfterBlock() {
        listener?.remove()
        listener = nil
        
        roomListener?.remove()
        roomListener = nil
        
        partnerListener?.remove()
        partnerListener = nil
        
        friendshipListener?.remove()
        friendshipListener = nil
    }
}
