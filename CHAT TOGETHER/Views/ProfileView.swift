import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

struct ProfileView: View {
    
    @EnvironmentObject var currentUserManager: CurrentUserManager
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var relationManager: RelationManager
    @Environment(\.dismiss) var dismiss
    @State private var showReportView = false
    @State private var showBlockAlert = false
    @State private var showEditProfile = false
    @State private var showRemoveFriendAlert = false
    @State private var isProcessing = false
    @State private var isProcessing111 = false
    @State private var showFriendLimitAlert = false
    let isCurrentUser: Bool
    let roomId: String?
    let userId: String?
    let roomType: ChatRoomType?
    let onUnfriend: (() -> Void)?
    let onBlock: (() -> Void)?
    
    init(user: AppUser, roomId: String? = nil, isCurrentUser: Bool = false, roomType: ChatRoomType? = nil, onUnfriend: (() -> Void)? = nil, onBlock: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(user: user))
        self.roomId = roomId
        self.isCurrentUser = isCurrentUser
        self.userId = user.uid
        self.roomType = roomType
        self.onUnfriend = onUnfriend
        self.onBlock = onBlock
    }
    
    var displayUser: AppUser? {
        if isCurrentUser {
            return currentUserManager.currentUser
        } else {
            return viewModel.user
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Avatar
                    if let avatar = displayUser?.avatar,
                       let url = URL(string: avatar) {
                        
                        KFImage(url)
                            .placeholder {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            .retry(maxCount: 2, interval: .seconds(1))
                            .cacheOriginalImage(true)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle().fill(Color.gray.opacity(0.2))
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 120, height: 120)
                    }
                    
                    if let user = displayUser {
                        Text(user.fullname)
                            .font(.title)
                            .bold()
                    }
                    
                    // CHỈ HIỆN KHI LÀ CHÍNH MÌNH
                    if isCurrentUser {
                        Button {
                            showEditProfile = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(
                                color: .blue.opacity(0.3),
                                radius: 8,
                                y: 4
                            )
                        }
                        .padding(.top, 8)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        
                        if let bio = displayUser?.bio, !bio.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("About me")
                                    .font(.headline)
                                Text(bio)
                            }
                        }
                        
                        if let createdAt = displayUser?.createdAt {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Member since")
                                    .font(.headline)
                                Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    if !isCurrentUser {
                        actionSection
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .onAppear {
                if !isCurrentUser {
                    if let userId = userId {
                        viewModel.fetchUser(uid: userId)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    EditProfileView()
                }
            }
            .fullScreenCover(isPresented: $showReportView) {
                if let roomId = roomId,
                   let reporterId = Auth.auth().currentUser?.uid,
                   let partnerId = viewModel.user?.uid {
                    
                    ReportView(
                        roomId: roomId,
                        reporterId: reporterId,
                        reportedUserId: partnerId,
                        roomType: roomType,
                        onBlock: onBlock
                    )
                }
            }
            .alert("Unfriend?", isPresented: $showRemoveFriendAlert) {
                
                Button("Cancel", role: .cancel) { }
                
                Button("Unfriend", role: .destructive) {
                    removeFriend()
                }
                
            } message: {
                Text("Would you like to unfriend? This can't be undone.")
            }
            .alert("Block User?", isPresented: $showBlockAlert) {
                
                Button("Cancel", role: .cancel) { }
                
                Button("Block", role: .destructive) {
                    blockUser()
                }
                
            } message: {
                Text("You will not be matched with this person again. This action cannot be undone. Are you sure you want to continue?")
            }
            .alert("Friend limit reached", isPresented: $showFriendLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You or this user has reached the maximum of 200 friends.")
            }
        }
        .disabled(isProcessing)
        .overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Processing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            
            friendActionButton
            
            Button {
                showBlockAlert = true
            } label: {
                Text("Block")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
            if roomId != nil {
                Button {
                    showReportView = true
                } label: {
                    Text("Report")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            }
        }
        .padding(.top, 10)
    }
    
    private var friendActionButton: some View {
        Group {
            if let partnerId = viewModel.user?.uid {
                
                if relationManager.isFriend(with: partnerId) {
                    
                    Button {
                        showRemoveFriendAlert = true
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Unfriend")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    }
                    
                } else if relationManager.didReceiveRequest(from: partnerId) {
                    
                    HStack(spacing: 10) {
                        
                        Button {
                            acceptRequest()
                        } label: {
                            Text("Accept")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                        
                        Button {
                            declineRequest()
                        } label: {
                            Text("Decline")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    }
                    
                } else {
                    
                    let isSent = relationManager.isRequestSent(to: partnerId)
                    
                    Button {
                        sendOrCancelRequest()
                    } label: {
                        Text(isSent ? "Cancel Request" : "Add Friend")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
        
    private func removeFriend() {
        guard let partnerId = viewModel.user?.uid else { return }
        guard !isProcessing else { return }
        
        isProcessing = true
        UserRelationService.shared.removeFriend(partnerId: partnerId) { success in
            DispatchQueue.main.async {
                isProcessing = false
                if success {
                    onUnfriend?()
                }
            }
        }
    }
    
    private func blockUser() {
        guard let partnerId = viewModel.user?.uid else { return }
        guard !isProcessing else { return }
        
        isProcessing = true

        UserRelationService.shared.blockUser(targetUserId: partnerId) { success in
            DispatchQueue.main.async {
                isProcessing = false
                
                if success {
                    onBlock?()
                }
            }
        }
    }
    
    private func sendOrCancelRequest() {
        guard let partnerId = viewModel.user?.uid else { return }
        
        if !relationManager.isRequestSent(to: partnerId),
           !relationManager.canAddFriend(),
           !relationManager.isFriend(with: partnerId) {
            
            showFriendLimitAlert = true
            return
        }
        
        // 🚀 CASE 1: CANCEL REQUEST
        if relationManager.isRequestSent(to: partnerId) {
            
            // optimistic
            relationManager.cancelRequestLocally(to: partnerId)
            
            UserRelationService.shared.cancelFriendRequest(to: partnerId) { success in
                DispatchQueue.main.async {
                    
                    if !success {
                        // rollback
                        relationManager.rollbackCancelRequest(to: partnerId)
                    }
                }
            }
            
        } else {
            
            // 🚀 CASE 2: SEND REQUEST
            
            // optimistic
            relationManager.sendRequestLocally(to: partnerId)
            
            UserRelationService.shared.sendFriendRequest(to: partnerId) { success in
                DispatchQueue.main.async {
                    
                    if !success {
                        // rollback
                        relationManager.rollbackSendRequest(to: partnerId)
                    }
                }
            }
        }
    }
    
    
    private func acceptRequest() {
        guard let partnerId = viewModel.user?.uid,
              let requestId = relationManager.requestId(from: partnerId) else { return }
        
        relationManager.markAsFriendLocally(with: partnerId)
        
        UserRelationService.shared.acceptFriendRequest(
            requestId: requestId,
            partnerId: partnerId
        ) { success in
            
            DispatchQueue.main.async {
                if !success {
                    // ❗ rollback nếu fail
                    relationManager.rollbackFriendState(with: partnerId)
                }
            }
        }
    }
    
    private func declineRequest() {
        guard let partnerId = viewModel.user?.uid,
              let requestId = relationManager.requestId(from: partnerId) else { return }
        
        UserRelationService.shared.declineFriendRequest(
            requestId: requestId
        ) { _ in }
    }
}
