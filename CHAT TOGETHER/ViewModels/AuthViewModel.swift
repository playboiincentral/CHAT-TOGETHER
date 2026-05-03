import FirebaseAuth
import SwiftUI
import AuthenticationServices
import FirebaseFunctions
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var userSession: FirebaseAuth.User?
    @Published var isLoading = false
    
    var currentUserManager: CurrentUserManager?
    private var currentNonce: String?
    
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
        let nonce = randomNonceString()
        currentNonce = nonce
        
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            
            guard let nonce = currentNonce else {
                print("❌ Missing nonce")
                return
            }
            
            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                print("❌ Unable to get identity token")
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            Task {
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    
                    print("✅ Apple login success:", result.user.uid)
                    
                    try await AuthService.shared.saveUserToFirestore(result.user)
                    
                } catch {
                    print("❌ Firebase login error:", error.localizedDescription)
                }
            }
            
        case .failure(let error):
            print("❌ Apple login error", error.localizedDescription)
        }
    }
    
    func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
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
    
    func signInAsGuest() async {
        do {
            isLoading = true
            try await AuthService.shared.signInAsGuest()
        } catch {
            print("❌ Guest login error:", error.localizedDescription)
        }
        isLoading = false
    }
}
