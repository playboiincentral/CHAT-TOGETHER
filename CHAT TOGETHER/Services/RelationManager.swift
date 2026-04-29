import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

class RelationManager: ObservableObject {
    
    @Published var friends: Set<String> = []
    @Published var sentRequests: Set<String> = []
    @Published var receivedRequests: [String: String] = [:] // userId: requestId
    @Published var users: [String: AppUser] = [:]
    
    private let db = Firestore.firestore()
    
    private var friendshipListener: ListenerRegistration?
    private var sentListener: ListenerRegistration?
    private var receivedListener: ListenerRegistration?
    
    private var isListening = false
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    let maxFriends = 200

    func canAddFriend() -> Bool {
        friends.count < maxFriends
    }
    
    // MARK: - START LISTEN
    func startListening() {
        guard let uid = currentUserId else { return }
        guard !isListening else { return }
        
        stopListening()
        
        isListening = true
        
        // 1️⃣ FRIENDS
        friendshipListener = db.collection("friendships")
            .whereField("users", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                var newFriends: Set<String> = []
                
                snapshot?.documents.forEach { doc in
                    let users = doc["users"] as? [String] ?? []
                    if let friendId = users.first(where: { $0 != uid }) {
                        newFriends.insert(friendId)
                    }
                }
                
                DispatchQueue.main.async {
                    self.friends = newFriends
                }
            }
        
        // 2️⃣ SENT REQUESTS
        sentListener = db.collection("friendRequests")
            .whereField("fromUserId", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                
                let ids = snapshot?.documents.compactMap {
                    $0["toUserId"] as? String
                } ?? []
                
                DispatchQueue.main.async {
                    self.sentRequests = Set(ids)
                }
            }
        
        // 3️⃣ RECEIVED REQUESTS
        receivedListener = db.collection("friendRequests")
            .whereField("toUserId", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                
                var map: [String: String] = [:]
                
                snapshot?.documents.forEach { doc in
                    if let fromId = doc["fromUserId"] as? String {
                        map[fromId] = doc.documentID
                    }
                }
                
                DispatchQueue.main.async {
                    self.receivedRequests = map
                }
            }
    }
    
    // MARK: - STOP LISTEN
    func stopListening() {
        friendshipListener?.remove()
        sentListener?.remove()
        receivedListener?.remove()
        
        friendshipListener = nil
        sentListener = nil
        receivedListener = nil
        
        isListening = false
    }
    
    // MARK: - HELPERS
    
    func isFriend(with userId: String) -> Bool {
        friends.contains(userId)
    }
    
    func isRequestSent(to userId: String) -> Bool {
        sentRequests.contains(userId)
    }
    
    func didReceiveRequest(from userId: String) -> Bool {
        receivedRequests[userId] != nil
    }
    
    func requestId(from userId: String) -> String? {
        receivedRequests[userId]
    }
    
    func mergeUsers(_ newUsers: [AppUser]) {
        for user in newUsers {
            users[user.id] = user
        }
    }
    
    func markAsFriendLocally(with userId: String) {
        friends.insert(userId)
        receivedRequests.removeValue(forKey: userId)
    }

    func rollbackFriendState(with userId: String) {
        friends.remove(userId)
        // optional: add lại request nếu cần
    }
    
    func removeFriendLocally(with userId: String) {
        friends.remove(userId)
    }
    
    func rollbackRemoveFriend(with userId: String) {
        friends.insert(userId)
    }
    
    func sendRequestLocally(to userId: String) {
        sentRequests.insert(userId)
    }
    
    func cancelRequestLocally(to userId: String) {
        sentRequests.remove(userId)
    }
    
    func rollbackSendRequest(to userId: String) {
        sentRequests.remove(userId)
    }
    
    func rollbackCancelRequest(to userId: String) {
        sentRequests.insert(userId)
    }
}
