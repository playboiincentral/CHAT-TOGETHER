import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift

final class AuthService {
    
    static let shared = AuthService()
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw URLError(.badURL)
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        
        let authResult = try await auth.signIn(with: credential)
        
        try await saveUserToFirestore(authResult.user)
    }
    
    func saveUserToFirestore(_ user: User) async throws {
        
        let docRef = db.collection("users").document(user.uid)
        
        let snapshot = try await docRef.getDocument()
        
        if !snapshot.exists {
            
            let newUser = AppUser(
                uid: user.uid,
                fullname: user.displayName ?? "No Name",
                email: user.email ?? "",
                gender: nil,
                bio: nil,
                avatar: nil,
                createdAt: Date(),
                dateOfBirth: nil,
                fullnameChangeCount: 0,
                fullnameLastResetAt: nil,
                fullnameLastChangedAt: nil,
                status: .active,
                warnings: 0,
                lastWarningAt: nil,
                lastSeenWarning: 0,
                isAdmin: false
            )
            
            try docRef.setData(from: newUser)
        }
    }
}
