import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct MessagesView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var isLoading = false
    @State private var selectedRoom: ChatRoom?
    @State private var showChat = false
    @State private var triggeredByUser = false
    @EnvironmentObject var relationManager: RelationManager
    @EnvironmentObject var currentUserManager: CurrentUserManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: Friends Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Friends")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                                    generator.impactOccurred()
                                    router.selectedTab = 1
                                } label: {
                                    RequestsCard(count: relationManager.receivedRequests.count)
                                }
                                ForEach(friendsVM.friendsWithoutRoom) { friend in
                                    Button {
                                        openChat(with: friend)
                                    } label: {
                                        FriendCard(friend: friend)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // MARK: Messages Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Messages")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        if friendsVM.roomsWithMessage.isEmpty {
                            Text("No messages yet")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        }
                        
                        ForEach(friendsVM.roomsWithMessage, id: \.roomId) { room in
                                                            
                                let partner = friendsVM.partners[room.roomId]
                                
                                Button {
                                    selectedRoom = room
                                    triggeredByUser = true
                                    showChat = true
                                } label: {
                                    MessageCard(
                                        room: room,
                                        currentUserId: Auth.auth().currentUser?.uid ?? "",
                                        partner: partner
                                    )
                                }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                friendsVM.fetchFriends()
                friendsVM.listenRooms()
                handlePendingRoom()
            }
            .fullScreenCover(isPresented: Binding(
                get: { showChat && triggeredByUser },
                set: { showChat = $0 }
            ), onDismiss: {
                triggeredByUser = false
            }) {
                if let room = selectedRoom {
                    ChatView(room: room, currentUserManager: currentUserManager)
                }
            }
        }
    }
    
    private func openChat(with friend: AppUser) {
        guard let friendId = friend.uid,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // 🔥 deterministic roomId
        let sorted = [currentUserId, friendId].sorted()
        let roomId = sorted.joined(separator: "_")
        
        let roomRef = Firestore.firestore()
            .collection("chatRooms")
            .document(roomId)
        
        roomRef.getDocument { snapshot, error in
            
            // ❌ fallback nếu lỗi mạng → vẫn mở chat
            if let snapshot = snapshot,
               snapshot.exists,
               let room = try? snapshot.data(as: ChatRoom.self) {
                
                DispatchQueue.main.async {
                    selectedRoom = room
                    triggeredByUser = true
                    showChat = true
                    isLoading = false
                }
                
                return
            }
            
            // ✅ nếu chưa có room → tạo TEMP ROOM đúng model ChatRoom
            let tempRoom = ChatRoom(
                id: roomId,
                users: sorted,
                type: .friend,
                status: .active,
                createdAt: nil,
                lastMessage: nil,
                lastMessageSenderId: nil,
                lastMessageAt: nil,
                lastReadAt: nil
            )
            
            DispatchQueue.main.async {
                selectedRoom = tempRoom
                triggeredByUser = true
                showChat = true
                isLoading = false
            }
            
            // 🔥 tạo room backend song song (không block UI)
            Functions.functions(region: "asia-southeast1")
                .httpsCallable("getOrCreateFriendRoom")
                .call(["friendId": friendId]) { _, error in
                    if let error = error {
                        print("create room error:", error)
                    }
                }
        }
    }
    
    private func handlePendingRoom() {
        
        guard let roomId = router.pendingRoomId else { return }
        
        // retry nhẹ vì Firestore có thể chưa load xong
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            
            if let room = friendsVM.rooms.first(where: {
                $0.roomId == roomId
            }) {
                selectedRoom = room
                triggeredByUser = true
                showChat = true
                router.pendingRoomId = nil
            } else {
                // retry lần 2 (an toàn)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.handlePendingRoom()
                }
            }
        }
    }
}

// MARK: FriendCard - Tinh chỉnh lại layout
struct FriendCard: View {
    let friend: AppUser
    
    var body: some View {
        VStack(spacing: 8) {
            if let avatar = friend.avatar, let url = URL(string: avatar) {
                KFImage(url)
                    .placeholder {
                        ProgressView()
                            .controlSize(.small)
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage(true)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.2))
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 100, height: 130)
            }
            
            Text(friend.fullname)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

struct RequestsCard: View {
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(UIColor.secondarySystemBackground))
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.primary)
                
                // 🔴 Badge
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 25, y: -35)
                }
            }
            .frame(width: 100, height: 130)
            
            Text(count == 1 ? "Request" : "Requests")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}
