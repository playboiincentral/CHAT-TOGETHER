//
//  AppEvent.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/30/26.
//

import Foundation
import SwiftUI

enum AppEvent {
    case userRemoved
    case userBlocked
}

extension Notification.Name {
    static let userRemoved = Notification.Name("userRemoved")
    static let userBlocked = Notification.Name("userBlocked")
}
