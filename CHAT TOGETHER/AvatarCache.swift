//
//  AvatarCache.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/24/26.
//

import Foundation

final class AvatarCache {
    static let shared = AvatarCache()
    
    private init() {}
    
    private var cache: [String: String] = [:]
    
    func get(_ userId: String) -> String? {
        cache[userId]
    }
    
    func set(_ userId: String, avatar: String?) {
        cache[userId] = avatar
    }
}
