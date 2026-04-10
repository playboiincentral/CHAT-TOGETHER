import FirebaseAuth
import SwiftUI
import AuthenticationServices
import FirebaseFunctions

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var userSession: FirebaseAuth.User?
    @Published var isLoading = false
    
    var currentUserManager: CurrentUserManager?
    
    init() {
        self.userSession = Auth.auth().currentUser
        listenToAuthState()
    }
    
    private func listenToAuthState() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.userSession = user
        }
    }
    
    func signInWithGoogle() async {
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            return
        }
        
        do {
            isLoading = true
            try await AuthService.shared.signInWithGoogle(presenting: rootVC)
        } catch {
            print(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        
        DispatchQueue.main.async {
            self.userSession = nil
            
            self.currentUserManager?.stopListening()
            self.currentUserManager?.currentUser = nil
        }
    }
    
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            print("Apple login success", auth)
            
        case .failure(let error):
            print("Apple login error", error.localizedDescription)
        }
    }
    
    func deleteAccount() async {
        guard Auth.auth().currentUser != nil else { return }
        
        isLoading = true
        
        do {
            // 🔥 Gọi Cloud Function
            try await Functions.functions(region: "asia-southeast1")
                .httpsCallable("deleteAccount")
                .call()
            
            // 🔥 Sign out local
            try Auth.auth().signOut()
            
            // 🔥 Reset state
            self.userSession = nil
            self.currentUserManager?.stopListening()
            self.currentUserManager?.currentUser = nil
            
        } catch {
            print("❌ Delete error:", error.localizedDescription)
        }
        
        isLoading = false
    }
}
