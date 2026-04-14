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
    @State private var previousDOB = ""
    
    init() {
        UIScrollView.disableSwipe()
    }
    
    var body: some View {
        VStack {
            TabView(selection: $onboardingVM.currentPage) {
                
                // 0️⃣ DOB
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text("Enter your date of birth *")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    TextField("MM/DD/YYYY", text: $onboardingVM.dobText)
                        .keyboardType(.numberPad)
                        .onChange(of: onboardingVM.dobText) { newValue in
                            defer { previousDOB = newValue }
                            
                            // Nếu đang xoá → không format
                            if newValue.count < previousDOB.count {
                                return
                            }
                            
                            onboardingVM.dobText = onboardingVM.formatDOB(newValue)
                        }
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor(), lineWidth: 2)
                        )
                        .padding(.horizontal)
                    
                    // ❗ Note
                    Text("You cannot change your date of birth after confirming it.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .tag(0)
                
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
                .tag(1)
                
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
                .tag(2)
                
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
                .tag(3)
                
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
                .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $onboardingVM.avatar)
            }
            
            HStack {
                // 🔙 Back
                Button(action: { previousPage() }) {
                    Text("Back")
                        .foregroundStyle(.gray)
                }
                // ❗ Ẩn Back ở page 0 và 1 (DOB + page sau DOB)
                .opacity(onboardingVM.currentPage <= 1 ? 0 : 1)
                .disabled(onboardingVM.currentPage <= 1)
                
                Spacer()
                
                // 🎯 PAGE 0: DOB
                if onboardingVM.currentPage == 0 {
                    
                    if onboardingVM.dobText.count == 10,
                       onboardingVM.isValidDOB(onboardingVM.dobText),
                       let age = onboardingVM.ageFromDOBString(onboardingVM.dobText) {
                        
                        Button(String(format: NSLocalizedString("confirm_age", comment: ""), age)) {
                            nextPage()
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                // 🎯 CÁC PAGE KHÁC
                else if onboardingVM.currentPage < 4 {
                    
                    // Avatar page (tag = 3 sau khi thêm DOB)
                    if onboardingVM.currentPage == 3 {
                        
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
                    
                }
                
                // 🎯 FINISH
                else {
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
    
    func borderColor() -> Color {
        // Chưa nhập đủ 10 ký tự → luôn màu xám
        if onboardingVM.dobText.count < 10 {
            return .gray
        }
        
        // Nhập đủ rồi mới validate
        return onboardingVM.isValidDOB(onboardingVM.dobText) ? .gray : .red
    }
    
    func previousPage() {
        if onboardingVM.currentPage > 0 {
            onboardingVM.currentPage -= 1
        }
    }
    
    func nextPage() {
        if onboardingVM.currentPage < 4 {
            onboardingVM.currentPage += 1
        }
    }
    
    func isNextEnabled() -> Bool {
        switch onboardingVM.currentPage {
        case 0:
            return onboardingVM.dobText.count == 10 &&
                   onboardingVM.isValidDOB(onboardingVM.dobText)
        case 1:
            return !onboardingVM.displayName.isEmpty
        case 2:
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
