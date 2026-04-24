import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    
    @Published var user: AppUser?
    private let db = Firestore.firestore()
    
    init(user: AppUser) {
        self.user = user
    }
    
    func fetchUser(uid: String) {
        
        db.collection("users")
            .document(uid)
            .getDocument { [weak self] snapshot, error in
                
                if let error = error {
                    print("❌ Fetch error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot,
                      snapshot.exists,
                      let user = try? snapshot.data(as: AppUser.self) else {
                    return
                }
                
                DispatchQueue.main.async {
                    self?.user = user
                }
            }
    }
    
    func reset() {
        user = nil
    }
}
