//
//  ChatRoomPreview.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/28/26.
//

import Foundation

struct ChatRoomPreview: Identifiable {
    let id: String
    let partner: AppUser
    let lastMessage: String
    let lastMessageAt: Date?
    let lastMessageSenderId: String?
}
