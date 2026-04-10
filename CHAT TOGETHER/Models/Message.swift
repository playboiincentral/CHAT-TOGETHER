//
//  Message.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable {
    var id: String
    var senderId: String
    var text: String
    var createdAt: Date?
    var reaction: String?
    var isAI: Bool
}
