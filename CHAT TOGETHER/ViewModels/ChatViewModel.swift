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
    @Published var isRoomReady = false
    @Published var showUnfriendAlert = false
    private var friendshipListener: ListenerRegistration?
    private var partnerListener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var hasReceivedFirstRoomSnapshot = false
    private var pendingMessages: [String] = []
    @Published var room: ChatRoom
    private var heartbeatTimer: Timer?
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var roomListener: ListenerRegistration?
    private let currentUserManager: CurrentUserManager
    
    init(room: ChatRoom, currentUserManager: CurrentUserManager) {
            self.room = room
            self.currentUserManager = currentUserManager
            
            self.isRoomActive = true
            self.hasReceivedFirstRoomSnapshot = false
            self.messages = []
            
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
            .addSnapshotListener(includeMetadataChanges: true) { snapshot, _ in
                
                guard let snapshot = snapshot else { return }
                
                // ❗ BỎ QUA CACHE
                if snapshot.metadata.isFromCache {
                    return
                }
                
                let documents = snapshot.documents
                
                DispatchQueue.main.async {
                    self.messages = documents.map { doc in
                        let timestamp = doc["createdAt"] as? Timestamp
                        let isAI = doc["isAI"] as? Bool ?? false
                        
                        return Message(
                            id: doc.documentID,
                            senderId: doc["senderId"] as? String ?? "",
                            senderName: doc["senderName"] as? String ?? "Unknown",
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
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, _ in
                
                guard let self = self else { return }
                guard let snapshot = snapshot else { return }
                
                // ❗ 1. BỎ CACHE
                if snapshot.metadata.isFromCache {
                    return
                }
                
                // ❗ 2. IGNORE SNAPSHOT ĐẦU (CỰC QUAN TRỌNG)
                if !self.hasReceivedFirstRoomSnapshot {
                    self.hasReceivedFirstRoomSnapshot = true
                    
                    if snapshot.exists,
                       let updatedRoom = try? snapshot.data(as: ChatRoom.self) {
                        DispatchQueue.main.async {
                            self.room = updatedRoom
                            self.isRoomReady = true
                            self.flushPendingMessages()
                        }
                    }
                    
                    return
                }
                
                // 🔥 3. ROOM BỊ XOÁ
                if !snapshot.exists {
                    
                    guard self.isRoomActive else { return }
                    
                    DispatchQueue.main.async {
                        self.isRoomActive = false
                        self.stopHeartbeat()
                        
                        self.showPartnerLeftAlert = true
                        self.cleanupAfterBlock()
                    }
                    
                    return
                }
                
                // 🔥 4. NORMAL FLOW
                guard let data = snapshot.data() else { return }
                
                if let updatedRoom = try? snapshot.data(as: ChatRoom.self) {
                    DispatchQueue.main.async {
                        self.room = updatedRoom
                        
                        if !self.isRoomReady {
                                                self.isRoomReady = true
                                                self.flushPendingMessages()
                                            }
                    }
                }
                
                let status = data["status"] as? String ?? ""
                let endedBy = data["endedBy"] as? String
                
                // 🔥 5. HANDLE ENDED
                if status == "ended" && self.isRoomActive {
                    
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
    
    private func flushPendingMessages() {
        pendingMessages.forEach { text in
            actuallySend(text)
        }
        pendingMessages.removeAll()
    }
    
    // MARK: - Send message
    
    func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messageText = ""

        guard isRoomActive else {
            print("Room is not active")
            return
        }

        // 🔥 room chưa ready → queue
        if !isRoomReady {
            pendingMessages.append(trimmed)
            return
        }

        actuallySend(trimmed)
    }
    
    private func actuallySend(_ text: String) {
        guard let currentUserId = userId else { return }

        let roomRef = db.collection("chatRooms").document(room.roomId)
        let messageRef = roomRef.collection("messages").document()
        let currentUserName = currentUserManager.currentUser?.fullname ?? "User"
        
        let batch = db.batch()

        // 🔹 message
        batch.setData([
            "senderId": currentUserId,
            "senderName": currentUserName,
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
            "reaction": NSNull(),
            "isAITrigger": text.range(of: "@tomi", options: .caseInsensitive) != nil
        ], forDocument: messageRef)

        // 🔹 room update
        var updateData: [String: Any] = [
            "lastActivityAt": FieldValue.serverTimestamp()
        ]

        if room.type == .friend {
            updateData["lastMessage"] = text
            updateData["lastMessageSenderId"] = currentUserId
            updateData["lastMessageAt"] = FieldValue.serverTimestamp()
        }

        batch.updateData(updateData, forDocument: roomRef)

        batch.commit { error in
            if let error = error {
                print("Send message error:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Leave room
    func leaveRoom(completion: @escaping () -> Void) {
        let roomId = room.roomId
        guard !roomId.isEmpty else { return }
        
        stopHeartbeat()
        
        let data: [String: Any] = [
            "roomId": roomId
        ]
        
        Functions.functions(region: "asia-southeast1")
            .httpsCallable("leaveRoom")
            .call(data) { [weak self] _, error in
                
                DispatchQueue.main.async {
                    completion() // 🔥 luôn gọi để tắt loading
                }
                
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
        isRoomActive = false
        
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
