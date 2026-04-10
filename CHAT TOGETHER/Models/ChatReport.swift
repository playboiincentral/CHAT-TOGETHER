//
//  ChatReport.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/1/26.
//

import Foundation
import FirebaseFirestore

enum ReportReason: String, Codable, CaseIterable {
    case harassment
    case sexualContent
    case hateSpeech
    case spam
    case discrimination
    case violence
    case scam
    case other
}

enum ReportStatus: String, Codable {
    case pending
    case resolved
    case rejected
}

struct ChatReport: Identifiable, Codable {
    
    var id: String
    
    var roomId: String
    
    var reporterId: String
    var reportedUserId: String
    
    var reasons: [ReportReason]
    var description: String?
    
    var status: ReportStatus = .pending
    
    var createdAt: Timestamp?
}
