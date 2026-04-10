import FirebaseFirestore

class UserService {
    
    static let shared = UserService()
    private let db = Firestore.firestore()
    
    func fetchUsers(
        userIds: [String],
        completion: @escaping ([AppUser]) -> Void
    ) {
        guard !userIds.isEmpty else {
            completion([])
            return
        }
        
        db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments { snapshot, error in
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let users = documents.compactMap {
                    try? $0.data(as: AppUser.self)
                }
                
                completion(users)
            }
    }
}
