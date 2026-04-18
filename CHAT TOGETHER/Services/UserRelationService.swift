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
    
    private let functions = Functions.functions(region: "asia-southeast1")
    
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
        
        // 1️⃣ Nếu partner đã gửi → accept bằng Cloud Function
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
                        
                        // 3️⃣ Tạo request
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
    
    // MARK: - ACCEPT REQUEST (🔥 FIXED: CALL CLOUD FUNCTION)
    func acceptFriendRequest(
        requestId: String,
        partnerId: String,
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "requestId": requestId,
            "partnerId": partnerId
        ]
        
        functions
            .httpsCallable("acceptFriendRequest")
            .call(data) { result, error in
                
                if let error = error as NSError? {
                    print("Accept error:", error.localizedDescription)
                    completion(false)
                    return
                }
                
                completion(true)
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
        
        functions
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
    
    // MARK: - BLOCK USER
    func blockUser(
        targetUserId: String,
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "blockedId": targetUserId
        ]
        
        functions
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
