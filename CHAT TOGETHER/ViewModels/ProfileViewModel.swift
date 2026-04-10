import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    
    @Published var user: AppUser?
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init(user: AppUser) {
        self.user = user
        
        guard let uid = user.uid else {
            print("❌ Missing UID")
            return
        }
        
        listenUser(uid: uid)
    }
    
    func reset() {
        removeListener()
        user = nil
    }
    
    func listenUser(uid: String) {
        removeListener()
        
        listener = db.collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                
                guard let snapshot = snapshot, snapshot.exists,
                      let data = snapshot.data() else {
                    DispatchQueue.main.async {
                        self?.user = nil
                    }
                    return
                }
                
                if let user = try? snapshot.data(as: AppUser.self) {
                    DispatchQueue.main.async {
                        self?.user = user
                    }
                } else {
                    print("❌ Mapping failed")
                }
            }
    }
    
    func removeListener() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        removeListener()
    }
}
