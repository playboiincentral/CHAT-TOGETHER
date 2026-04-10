//
//  FriendRequest.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/19/26.
//

import Foundation
import FirebaseFirestore

struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let fromUserId: String
    let toUserId: String
    let status: String
    let createdAt: Timestamp
}
