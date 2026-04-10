//
//  AppUser.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 2/13/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

enum Gender: String, Codable, CaseIterable {
    case male
    case female
}

struct AppUser: Codable, Identifiable, Hashable {
    @DocumentID var uid: String?
    
    var id: String {
        uid ?? UUID().uuidString
    }
    
    var fullname: String
    var email: String
    var gender: Gender?
    var bio: String?
    var avatar: String?
    var createdAt: Date?
}
