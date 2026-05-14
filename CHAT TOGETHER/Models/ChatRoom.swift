import Foundation
import FirebaseFirestore

struct ChatRoom: Identifiable, Codable {
    
    @DocumentID var id: String?
    
    var roomId: String {
        id ?? ""
    }
    
    // Immutable
    var users: [String]
    
    var type: ChatRoomType
    
    // Dynamic
    var activeUsers: [String]?
    
    var status: RoomStatus
    
    var createdAt: Timestamp?
    var endedAt: Timestamp?
    var endedBy: String?
        
    var lastActivityAt: Timestamp?
    
    var lastMessage: String?
    var lastMessageSenderId: String?
    var lastMessageAt: Timestamp?
    var lastReadAt: [String: Timestamp]?
}
