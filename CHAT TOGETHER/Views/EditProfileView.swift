//
//  EditProfileView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/14/26.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import Kingfisher

struct EditProfileView: View {
    @EnvironmentObject var currentUserManager: CurrentUserManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var user: AppUser? {
        currentUserManager.currentUser
    }
    
    @State private var fullname: String = ""
    @State private var bio: String = ""
    @State private var selectedGender: Gender? = nil
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var avatarURL: String? = nil
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasEdited = false
    
    var isValid: Bool {
        !fullname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // MARK: Avatar
                
                avatarView
                
                PhotosPicker("Change Avatar", selection: $selectedItem, matching: .images)
                    .onChange(of: selectedItem) { newItem in
                        loadImage(from: newItem)
                    }
                    .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 26) {
                    // MARK: Name
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Display Name")
                            .font(.headline)
                        
                        TextField("Enter your name", text: $fullname)
                            .font(.system(size: 17, weight: .medium))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary, lineWidth: 1.5)
                            )
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .onChange(of: fullname) { newValue in
                                hasEdited = true
                                let cleaned = newValue.replacingOccurrences(of: "\n", with: "")
                                
                                if cleaned.count > 32 {
                                    fullname = String(cleaned.prefix(32))
                                } else {
                                    fullname = cleaned
                                }
                            }
                    }
                    
                    // MARK: Gender
                    genderSelector
                    
                    // MARK: Bio
                    bioEditor
                    
                }
            }
            .padding()
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .foregroundStyle(.primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveProfile()
                } label: {
                    ZStack {
                        Text("Save")
                            .foregroundStyle(.blue)
                            .opacity(isSaving ? 0 : 1)
                        
                        ProgressView()
                            .opacity(isSaving ? 1 : 0)
                    }
                    .frame(width: 50)
                }
                .disabled(isSaving || !isValid)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if let user { syncUser(user) }
        }
        .onChange(of: user) { newUser in
            guard let newUser, !hasEdited else { return }
            syncUser(newUser)
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = selectedImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURL,
                          let url = URL(string: avatarURL) {
                    KFImage(url)
                        .placeholder {
                            ProgressView()
                                .controlSize(.small)
                        }
                        .retry(maxCount: 2, interval: .seconds(1))
                        .cacheOriginalImage(true)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .shadow(radius: 5)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var genderSelector: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Gender")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                
                VStack(alignment: .leading, spacing: 12) {
                    genderRow(title: "Woman", gender: .female)
                    genderRow(title: "Man", gender: .male)
                }
                
                Text("Selecting your gender will determine who you are matched with.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    @ViewBuilder
    private func genderRow(title: String, gender: Gender) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: selectedGender == gender ? "largecircle.fill.circle" : "circle")
                .foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedGender = gender }
    }
    
    @ViewBuilder
    private var bioEditor: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Bio")
                .font(.headline)
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $bio)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary, lineWidth: 1.5)
                    )
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .onChange(of: bio) { newValue in
                        if newValue.count > 150 {
                            bio = String(newValue.prefix(150))
                        }
                    }
                
                Text("\(bio.count)/150")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(8)
            }
        }
    }
    
    func syncUser(_ user: AppUser) {
        fullname = user.fullname
        bio = user.bio ?? ""
        selectedGender = user.gender
        avatarURL = user.avatar
    }
    
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.selectedImageData = data
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let trimmedName = fullname.trimmingCharacters(in: .whitespaces)
        
        if trimmedName.isEmpty {
            errorMessage = "Name must be at least 1 character"
            return
        }
        
        fullname = trimmedName
        
        isSaving = true
        errorMessage = nil
        
        if let imageData = selectedImageData {
            uploadAvatar(uid: uid, imageData: imageData)
        } else {
            updateFirestore(uid: uid, avatarURL: avatarURL)
        }
    }
    
    private func uploadAvatar(uid: String, imageData: Data) {
        let ref = storage.reference().child("avatars/\(uid).jpg")
        
        ref.putData(imageData) { _, error in
            if let error {
                errorMessage = error.localizedDescription
                isSaving = false
                return
            }
            
            ref.downloadURL { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        self.avatarURL = url.absoluteString
                    }
                    updateFirestore(uid: uid, avatarURL: url.absoluteString)
                }
            }
        }
    }
    
    private func updateFirestore(uid: String, avatarURL: String?) {
        
        var data: [String: Any] = [
            "fullname": fullname,
            "bio": bio
        ]
        
        if let gender = selectedGender {
            data["gender"] = gender.rawValue
        }
        
        if let avatarURL {
            data["avatar"] = avatarURL
        }
        
        db.collection("users")
            .document(uid)
            .setData(data, merge: true) { error in
                
                isSaving = false
                
                if let error {
                    errorMessage = error.localizedDescription
                    return
                }
                
                dismiss()
            }
    }
}
