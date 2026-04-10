import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

class UserRelationService {
    
    static let shared = UserRelationService()
    
    private let db = Firestore.firestore()
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - SEND FRIEND REQUEST
    func sendFriendRequest(
        to partnerId: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUserId = currentUserId,
              currentUserId != partnerId else {
            completion(false)
            return
        }
        
        let requestsRef = db.collection("friendRequests")
        
        // 1️⃣ Check nếu partner đã gửi cho mình → auto accept
        requestsRef
            .whereField("fromUserId", isEqualTo: partnerId)
            .whereField("toUserId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                
                if let doc = snapshot?.documents.first {
                    self.acceptFriendRequest(
                        requestId: doc.documentID,
                        partnerId: partnerId,
                        completion: completion
                    )
                    return
                }
                
                // 2️⃣ Check mình đã gửi chưa
                requestsRef
                    .whereField("fromUserId", isEqualTo: currentUserId)
                    .whereField("toUserId", isEqualTo: partnerId)
                    .whereField("status", isEqualTo: "pending")
                    .getDocuments { snapshot, error in
                        
                        if snapshot?.documents.isEmpty == false {
                            completion(false)
                            return
                        }
                        
                        // 3️⃣ Tạo request mới
                        let data: [String: Any] = [
                            "fromUserId": currentUserId,
                            "toUserId": partnerId,
                            "status": "pending",
                            "createdAt": Timestamp()
                        ]
                        
                        requestsRef.addDocument(data: data) { error in
                            completion(error == nil)
                        }
                    }
            }
    }
    
    // MARK: - CANCEL REQUEST
    func cancelFriendRequest(
        to partnerId: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUserId = currentUserId else {
            completion(false)
            return
        }
        
        db.collection("friendRequests")
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: partnerId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                
                let batch = self.db.batch()
                
                snapshot?.documents.forEach {
                    batch.deleteDocument($0.reference)
                }
                
                batch.commit { error in
                    completion(error == nil)
                }
            }
    }
    
    // MARK: - ACCEPT REQUEST
    func acceptFriendRequest(
        requestId: String,
        partnerId: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUserId = currentUserId else {
            completion(false)
            return
        }
        
        let batch = db.batch()
        
        let sortedUsers = [currentUserId, partnerId].sorted()
        let friendshipId = sortedUsers.joined(separator: "_")
        
        let requestRef = db.collection("friendRequests").document(requestId)
        let friendshipRef = db.collection("friendships").document(friendshipId)
        
        // tạo friendship
        batch.setData([
            "users": sortedUsers,
            "createdAt": Timestamp()
        ], forDocument: friendshipRef)
        
        // xoá request
        batch.deleteDocument(requestRef)
        
        batch.commit { error in
            completion(error == nil)
        }
    }
    
    // MARK: - DECLINE REQUEST
    func declineFriendRequest(
        requestId: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("friendRequests")
            .document(requestId)
            .delete { error in
                completion(error == nil)
            }
    }
    
    // MARK: - REMOVE FRIEND
    func removeFriend(
        partnerId: String,
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "partnerId": partnerId
        ]
        
        Functions.functions(region: "asia-southeast1")
            .httpsCallable("removeFriend")
            .call(data) { result, error in
                
                if let error = error {
                    print("Remove friend error:", error)
                    completion(false)
                    return
                }
                
                completion(true)
            }
    }
    
    // MARK: - BLOCK USER (reuse của bạn)
    func blockUser(
        targetUserId: String,
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "blockedId": targetUserId
        ]
        
        Functions.functions(region: "asia-southeast1")
            .httpsCallable("blockUser")
            .call(data) { result, error in
                
                if let error = error {
                    print("Block error:", error)
                    completion(false)
                    return
                }
                
                completion(true)
            }
    }
}
