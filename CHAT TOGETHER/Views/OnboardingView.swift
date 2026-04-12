import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

struct OnboardingView: View {
    @EnvironmentObject var onboardingVM: OnboardingViewModel
    @EnvironmentObject var currentUserManager: CurrentUserManager
    
    @State private var showImagePicker = false

    init() {
        UIScrollView.disableSwipe()
    }
    
    var body: some View {
        VStack {
            TabView(selection: $onboardingVM.currentPage) {
                
                // 1️⃣ Display Name
                VStack(spacing: 20) {
                    Spacer()
                    Text("Enter your display name *").font(.title2).fontWeight(.bold)
                    TextField("Display Name", text: $onboardingVM.displayName)
                        .font(.system(size: 17, weight: .medium))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary, lineWidth: 1.5)
                        )
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal)
                        .onChange(of: onboardingVM.displayName) { newValue in
                            
                            let cleaned = newValue.replacingOccurrences(of: "\n", with: "")
                            
                            if cleaned.count > 32 {
                                onboardingVM.displayName = String(cleaned.prefix(32))
                            } else {
                                onboardingVM.displayName = cleaned
                            }
                        }
                    Spacer()
                }
                .tag(0)
                
                // 2️⃣ Gender
                VStack(spacing: 30) {
                    Spacer()
                    Text("Select your gender *").font(.title2).fontWeight(.bold)
                    
                    // Woman
                    Button(action: { onboardingVM.gender = .female }) {
                        HStack {
                            Text("Woman")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: onboardingVM.gender == .female ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(onboardingVM.gender == .female ? .pink : .gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Man
                    Button(action: { onboardingVM.gender = .male }) {
                        HStack {
                            Text("Man")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: onboardingVM.gender == .male ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(onboardingVM.gender == .male ? .pink : .gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .tag(1)
                
                // 3️⃣ Avatar (Optional)
                VStack(spacing: 20) {
                    Spacer()
                    Text("Choose an avatar").font(.title2).fontWeight(.bold)
                    
                    if let avatar = onboardingVM.avatar {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .foregroundColor(.gray)
                    }
                    
                    Button("Pick Avatar") { showImagePicker = true }
                        .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .tag(2)
                
                // 4️⃣ Bio (Optional)
                VStack(spacing: 20) {
                    Spacer()
                    Text("Write a bio").font(.title2).fontWeight(.bold)
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $onboardingVM.bio)
                            .frame(height: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary, lineWidth: 1.5)
                            )
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .onChange(of: onboardingVM.bio) { newValue in
                                if newValue.count > 150 {
                                    onboardingVM.bio = String(newValue.prefix(150))
                                }
                            }
                        
                        Text("\(onboardingVM.bio.count)/150")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $onboardingVM.avatar)
            }
            
            HStack {
                // Back
                Button(action: { previousPage() }) {
                    Text("Back")
                        .foregroundStyle(.gray)
                }
                .opacity(onboardingVM.currentPage == 0 ? 0 : 1)
                .disabled(onboardingVM.currentPage == 0)
                
                Spacer()
                
                if onboardingVM.currentPage < 3 {
                    
                    // 🎯 Page Avatar (tag = 2)
                    if onboardingVM.currentPage == 2 {
                        
                        if onboardingVM.avatar != nil {
                            Button("Next") { nextPage() }
                                .foregroundStyle(.blue)
                        } else {
                            Button("Skip") { nextPage() }
                                .foregroundStyle(.blue)
                        }
                        
                    } else {
                        Button("Next") { nextPage() }
                            .foregroundStyle(isNextEnabled() ? .blue : .gray.opacity(0.5))
                            .disabled(!isNextEnabled())
                    }
                    
                } else {
                    Button("Finish") { finishOnboarding() }
                        .foregroundStyle(.blue)
                }
            }
            .padding()
        }
        .disabled(onboardingVM.isLoading)
        .overlay {
            if onboardingVM.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Updating...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func previousPage() {
        if onboardingVM.currentPage > 0 {
            onboardingVM.currentPage -= 1
        }
    }
    
    func nextPage() {
        if onboardingVM.currentPage < 3 {
            onboardingVM.currentPage += 1
        }
    }
    
    func isNextEnabled() -> Bool {
        switch onboardingVM.currentPage {
        case 0:
            return !onboardingVM.displayName.isEmpty
        case 1:
            return onboardingVM.gender != nil
        default:
            return true
        }
    }
    
    func finishOnboarding() {
        onboardingVM.isLoading = true
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if let avatar = onboardingVM.avatar {
            uploadAvatar(uid: uid, image: avatar) { avatarURL in
                saveUserData(avatarURL: avatarURL)
            }
        } else {
            saveUserData(avatarURL: nil)
        }
    }
    
    func saveUserData(avatarURL: String?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(uid)
        
        var data: [String: Any] = [
            "fullname": onboardingVM.displayName
        ]
        if let gender = onboardingVM.gender { data["gender"] = gender.rawValue }
        if let avatarURL = avatarURL { data["avatar"] = avatarURL }
        if !onboardingVM.bio.isEmpty { data["bio"] = onboardingVM.bio }
        
        userRef.setData(data, merge: true) { error in
            DispatchQueue.main.async {
                onboardingVM.isLoading = false
                if let error = error {
                    print("❌ Error saving user:", error.localizedDescription)
                } else {
                    print("✅ Onboarding finished")
                }
            }
        }
    }
    
    func uploadAvatar(uid: String, image: UIImage, completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference().child("avatars/\(uid).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("❌ Upload avatar failed:", error.localizedDescription)
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, _ in
                completion(url?.absoluteString)
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> some UIViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider else { return }
            if item.canLoadObject(ofClass: UIImage.self) {
                item.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

extension UIScrollView {
    static func disableSwipe() {
        UIScrollView.appearance().isScrollEnabled = false
    }
}
