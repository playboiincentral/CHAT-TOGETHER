import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class FriendsViewModel: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var rooms: [ChatRoom] = []
    @Published var partners: [String: AppUser] = [:]
    @Published var didLoadRooms = false
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var roomListener: ListenerRegistration?
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var friendsWithoutRoom: [AppUser] {
        guard let currentUserId = userId else { return friends }
        
        // 🔥 CHƯA load rooms → show hết
        guard didLoadRooms else {
            return []
        }
        
        let usersInRooms = Set(
            rooms
                .filter { $0.lastMessageAt != nil }
                .compactMap { room in
                    room.users.first { $0 != currentUserId }
                }
        )
        
        return friends.filter { friend in
            guard let id = friend.uid else { return false }
            return !usersInRooms.contains(id)
        }
    }
    
    var roomsWithMessage: [ChatRoom] {
        rooms.filter { $0.lastMessageAt != nil }
    }
    
    func fetchFriends() {
        guard let currentUserId = userId else { return }
        
        db.collection("friendships")
            .whereField("users", arrayContains: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                let friendIds = documents.compactMap { doc -> String? in
                    let users = doc["users"] as? [String] ?? []
                    return users.first { $0 != currentUserId }
                }
                
                if friendIds.isEmpty {
                    self.friends = []
                    return
                }
                
                self.fetchUsers(with: friendIds)
            }
    }
    
    func isUnread(room: ChatRoom, currentUserId: String) -> Bool {
        
        guard let lastMessageAt = room.lastMessageAt else {
            return false
        }
        
        guard room.lastMessageSenderId != currentUserId else {
            return false
        }
        
        guard let lastRead = room.lastReadAt?[currentUserId] else {
            return true
        }
        
        return lastRead.dateValue() < lastMessageAt.dateValue()
    }
    
    private func fetchUsers(with ids: [String]) {
        
        let group = DispatchGroup()
        var result: [AppUser] = []
        
        ids.forEach { id in
            group.enter()
            
            db.collection("users")
                .document(id)
                .getDocument { snapshot, _ in
                    if let user = try? snapshot?.data(as: AppUser.self) {
                        result.append(user)
                    }
                    group.leave()
                }
        }
        
        group.notify(queue: .main) {
            self.friends = result
            self.listenRooms()
            print("🔥 friends updated:", result.count)
        }
    }
    
    func listenRooms() {
        guard let userId = userId else { return }
        
        roomListener?.remove()
        
        roomListener = db.collection("chatRooms")
            .whereField("type", isEqualTo: "friend")
            .whereField("users", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                guard let currentUserId = self.userId else { return }

                let rooms = documents.compactMap { doc -> ChatRoom? in
                    guard let room = try? doc.data(as: ChatRoom.self) else { return nil }
                    
                    let partnerId = room.users.first { $0 != currentUserId }
                    
                    if let partnerId = partnerId,
                       self.friends.contains(where: { $0.uid == partnerId }) {
                        return room
                    }
                    
                    return nil
                }
                
                // 🔥 SORT LOCAL
                let sorted = rooms.sorted {
                    ($0.lastMessageAt?.dateValue() ?? Date.distantPast) >
                    ($1.lastMessageAt?.dateValue() ?? Date.distantPast)
                }
                
                let newRoomIds = Set(sorted.map { $0.roomId })

                DispatchQueue.main.async {
                    self.rooms = sorted
                    self.didLoadRooms = true
                    // 🔥 CLEAN partners
                    self.partners = self.partners.filter { newRoomIds.contains($0.key) }
                }
                
                sorted.forEach { room in
                    self.fetchPartnerIfNeeded(for: room)
                }
            }
    }
    
    private func fetchPartnerIfNeeded(for room: ChatRoom) {
            guard partners[room.roomId] == nil else { return }
            fetchPartner(for: room)
        }

    private func fetchPartner(for room: ChatRoom) {
            guard let currentUserId = userId else { return }
            
            guard let partnerId = room.users.first(where: { $0 != currentUserId }) else {
                return
            }
            
            db.collection("users")
                .document(partnerId)
                .getDocument { [weak self] snapshot, _ in
                    
                    guard let self = self else { return }
                    guard let snapshot = snapshot else { return }
                    
                    if let user = try? snapshot.data(as: AppUser.self) {
                        DispatchQueue.main.async {
                            self.partners[room.roomId] = user
                        }
                    }
                }
        }

    deinit {
            listener?.remove()
            roomListener?.remove()
        }
}
