//
//  Friendship.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/25/26.
//

import Foundation
import FirebaseCore

struct Friendship: Identifiable, Codable {
    var id: String
    var users: [String]
    var createdAt: Timestamp
}
