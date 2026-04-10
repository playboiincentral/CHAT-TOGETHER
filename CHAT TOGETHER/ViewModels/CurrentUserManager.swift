import Foundation
import FirebaseAuth
import FirebaseFirestore

class CurrentUserManager: ObservableObject {
    @Published var currentUser: AppUser?
    
    private var listener: ListenerRegistration?
    
    func startListening() {
        guard listener == nil else { return }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No UID")
            return
        }
        
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
        
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firestore error:", error.localizedDescription)
                return
            }
            
            guard let snapshot = snapshot,
                  let data = snapshot.data() else {
                print("❌ No data")
                return
            }
            
            if let user = try? snapshot.data(as: AppUser.self) {
                DispatchQueue.main.async {
                    self.currentUser = user
                }
            } else {
                print("❌ Mapping failed")
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        currentUser = nil
    }
    
    func updateCurrentUser(displayName: String,
                           gender: Gender?,
                           avatar: String?,
                           bio: String?) {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let ref = Firestore.firestore().collection("users").document(uid)
        
        var data: [String: Any] = [
            "fullname": displayName
        ]
        
        if let gender = gender {
            data["gender"] = gender.rawValue
        }
        if let avatar = avatar {
            data["avatar"] = avatar
        }
        if let bio = bio {
            data["bio"] = bio
        }
        
        ref.setData(data, merge: true) { error in
            if let error = error {
                print("❌ Failed updating user:", error.localizedDescription)
            } else {
                print("✅ User updated successfully")
            }
        }
    }
    
}
