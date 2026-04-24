//
//  MessageCard.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 3/30/26.
//

import SwiftUI

struct MessageCard: View {
    
    let room: ChatRoom
    let currentUserId: String
    let partner: AppUser?
    
    var isUnread: Bool {
        guard let lastMessageAt = room.lastMessageAt else { return false }
        let lastRead = room.lastReadAt?[currentUserId]
        return lastRead == nil || lastRead!.dateValue() < lastMessageAt.dateValue()
    }
    
    var isMyLastMessage: Bool {
        room.lastMessageSenderId == currentUserId
    }
    
    var body: some View {
        HStack(spacing: 9) {
            
            // MARK: - Avatar
            AsyncImage(url: URL(string: partner?.avatar ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            
            // MARK: - Name + Message
            VStack(alignment: .leading, spacing: 8) {
                
                // Name
                Text(partner?.fullname ?? "Unknown")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Message
                Text(lastMessageText())
                    .font(.system(size: 16))
                    .fontWeight(isMyLastMessage ? .regular : (isUnread ? .semibold : .regular))
                    .foregroundColor(isMyLastMessage ? .secondary : (isUnread ? .primary : .secondary))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // MARK: - Time + Unread dot
            if let date = room.lastMessageAt?.dateValue() {
                VStack(alignment: .trailing, spacing: 6) {
                    
                    Text(timeString(from: date))
                        .font(.system(size: 14))
                        .fontWeight(isMyLastMessage ? .regular : (isUnread ? .semibold : .regular))
                        .foregroundColor(isMyLastMessage ? .secondary : (isUnread ? .primary : .secondary))
                    
                    if isUnread && !isMyLastMessage {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
}

// MARK: - Helpers
extension MessageCard {
    
    private func lastMessageText() -> String {
        guard let text = room.lastMessage else { return "" }
        
        if room.lastMessageSenderId == currentUserId {
            return "You: \(text)"
        } else {
            return text
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        
        return formatter.string(from: date)
    }
}
