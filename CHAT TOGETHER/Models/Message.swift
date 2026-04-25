//
//  Message.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    var id: String
    var senderId: String
    var senderName: String
    var text: String
    var createdAt: Date?
    var reactions: [String: String]?
    var isAI: Bool
    var replyToMessageId: String?
    var replyPreview: String?
}
