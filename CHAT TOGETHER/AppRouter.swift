//
//  AppRouter.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/28/26.
//

import Foundation
import SwiftUI

final class AppRouter: ObservableObject {
    @Published var selectedTab: Int = 0    
    @Published var pendingRoomId: String?
}
