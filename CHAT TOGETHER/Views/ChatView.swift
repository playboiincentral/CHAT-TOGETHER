import SwiftUI
import FirebaseFunctions

struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var relationManager: RelationManager
    @StateObject private var viewModel: ChatViewModel
    @State private var showLeaveAlert = false
    @State private var showProfile = false
    @State private var showMoreSheet = false
    @State private var showReportView = false
    @State private var showBlockAlert = false
    @State private var selectedUser: AppUser?
    @State private var showMentionList = false
    @State private var mentionQuery = ""
    @State private var hasScrolledToBottom = false
    @State private var isProcessing = false
    
    init(room: ChatRoom) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room))
    }
    
    // MARK: - Formatters
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // MARK: - Reactions
    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "😡"]
    
    @State private var selectedMessage: Message?
    @State private var showReactionPicker = false
    @State private var showRemoveFriendAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                headerView
                Divider()
                messageSection
                Divider()
                if showMentionList {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        Button {
                            insertMention("Togi")
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color.pink)
                                    .frame(width: 30, height: 30)
                                    .overlay(Text("T").foregroundColor(.white))
                                
                                Text("Togi")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding()
                        }
                        
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                }
                inputSection
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.handleOnAppear()
            }
            .onChange(of: viewModel.shouldDismiss) { value in
                guard value else { return }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
            .onTapGesture {
                showMentionList = false
            }
            .alert("Do you want to end the conversation?", isPresented: $showLeaveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    isProcessing = true
                    viewModel.leaveRoom() {
                        isProcessing = false
                    }
                }
            }
            .alert("The other person has left the room.", isPresented: $viewModel.showPartnerLeftAlert) {
                Button("OK") {
                    dismiss()
                }
            }
            .alert("Unfriend?", isPresented: $showRemoveFriendAlert) {
                
                Button("Cancel", role: .cancel) { }
                
                Button("Remove", role: .destructive) {
                    removeFriend()
                }
                
            } message: {
                Text("Are you sure you want to remove this friend?")
            }
            .alert("You are no longer friends.", isPresented: $viewModel.showUnfriendAlert) {
                Button("OK") {
                    dismiss()
                }
            }
            .alert("Block user?", isPresented: $showBlockAlert) {
                
                Button("Cancel", role: .cancel) { }
                
                Button("Block", role: .destructive) {
                    blockUser()
                }
                
            } message: {
                Text("You will not be matched with this person again. This action cannot be undone.")
            }
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView("Processing...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .sheet(isPresented: $showReactionPicker) {
                if let message = selectedMessage {
                    HStack(spacing: 25) {
                        ForEach(reactions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.largeTitle)
                                .onTapGesture {
                                    handleReactionTap(emoji, for: message)
                                }
                        }
                    }
                    .padding()
                    .presentationDetents([.height(110)])
                }
            }
            .sheet(item: $selectedUser) { partner in
                ProfileView(
                    user: partner,
                    roomId: viewModel.room.id,
                    isCurrentUser: false
                )
            }
            .confirmationDialog("Options", isPresented: $showMoreSheet) {
                
                Button("Block", role: .destructive) {
                    showBlockAlert = true
                }
                
                Button("Report", role: .destructive) {
                    showReportView = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
            .navigationDestination(isPresented: $showReportView) {
                if let userId = viewModel.userId,
                   let partnerId = viewModel.partner?.uid {
                    
                    ReportView(
                        roomId: viewModel.room.roomId,
                        reporterId: userId,
                        reportedUserId: partnerId
                    )
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 20) {
            
            Button {
                handleExit()
            } label: {
                Image(systemName: viewModel.room.type == .random
                      ? "rectangle.portrait.and.arrow.right"
                      : "chevron.left")
                .foregroundColor(viewModel.room.type == .random ? .red : .primary)
            }
            
            // Avatar + name
            if let partner = viewModel.partner {
                Button {
                    print("Tapped avatar, partner:", viewModel.partner?.fullname ?? "nil")
                    selectedUser = viewModel.partner
                } label: {
                    HStack(spacing: 10) {
                        
                        AsyncImage(url: URL(string: partner.avatar ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        
                        Text(partner.fullname)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
            
            // 🔥 FRIEND ACTION
            if let partnerId = viewModel.partner?.uid {
                
                if relationManager.isFriend(with: partnerId) {
                    
                    Button {
                        showRemoveFriendAlert = true
                    } label: {
                        Image(systemName: "person.fill.checkmark")
                            .foregroundStyle(.green)
                    }
                    
                } else if relationManager.didReceiveRequest(from: partnerId) {
                    
                    HStack(spacing: 15) {
                        
                        Button {
                            acceptRequest()
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                        
                        Button {
                            declineRequest()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.red)
                        }
                    }
                    
                } else {
                    
                    Button {
                        sendOrCancelRequest()
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(
                                relationManager.isRequestSent(to: partnerId)
                                ? .gray
                                : .green
                            )
                    }
                }
            }
            
            // More button
            Button {
                showMoreSheet = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var messageSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        let previous = index > 0 ? viewModel.messages[index - 1] : nil
                        let next = index < viewModel.messages.count - 1 ? viewModel.messages[index + 1] : nil
                        let position = messagePosition(current: message, previous: previous, next: next)
                        
                        let showAvatar = (position == .bottom || position == .single)
                        
                        if shouldShowDate(current: message, previous: previous) {
                            dateSeparator(for: message)
                        }
                        
                        MessageRow(
                            message: message,
                            isCurrentUser: message.senderId == viewModel.userId,
                            partner: viewModel.partner,
                            timeFormatter: timeFormatter,
                            showAvatar: showAvatar,
                            position: position,
                            onTapAvatar: { user in
                                selectedUser = user
                            },
                            onLongPress: { message in
                                selectedMessage = message
                                showReactionPicker = true
                            },
                            onTapReaction: { message in
                                viewModel.removeReaction(messageId: message.id)
                            }
                        )
                        .id(message.id)
                        .padding(.top, topSpacing(for: position))
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                guard let lastId = viewModel.messages.last?.id else { return }
                
                if !hasScrolledToBottom {
                    DispatchQueue.main.async {
                        proxy.scrollTo(lastId, anchor: .bottom)
                        hasScrolledToBottom = true
                    }
                } else {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputSection: some View {
        HStack {
            TextField("message... (type @Togi to ask Togi)", text: $viewModel.messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.send)
                .onChange(of: viewModel.messageText) { text in
                    handleMention(text)
                }
                .onSubmit {
                    viewModel.sendMessage()
                }
            
            Button {
                viewModel.sendMessage()
            } label: {
                Text("Send")
                    .foregroundStyle(.pink)
            }
        }
        .padding()
    }
    
    private func handleMention(_ text: String) {
        if let range = text.range(of: "@\\w*$", options: .regularExpression) {
            let query = String(text[range]).lowercased()
            
            if query.contains("@") {
                mentionQuery = query.replacingOccurrences(of: "@", with: "")
                showMentionList = true
                return
            }
        }
        
        showMentionList = false
    }
    
    private func handleExit() {
        if viewModel.room.type == .random {
            showLeaveAlert = true
        } else {
            dismiss()
        }
    }
    
    private func handleReactionTap(_ emoji: String, for message: Message) {
        guard message.senderId != viewModel.userId else { return }
        
        if message.reaction == emoji {
            viewModel.removeReaction(messageId: message.id)
        } else {
            viewModel.updateReaction(
                messageId: message.id,
                senderId: message.senderId,
                reaction: emoji
            )
        }
        
        showReactionPicker = false
    }
    
    private func insertMention(_ name: String) {
        guard let range = viewModel.messageText.range(of: "@\\w*$", options: .regularExpression) else {
            return
        }
        
        viewModel.messageText.replaceSubrange(range, with: "@\(name) ")
        showMentionList = false
    }
    
    private func reactionView(for message: Message) -> some View {
        Group {
            if let reaction = message.reaction {
                Text(reaction)
                    .font(.caption)
                    .padding(6)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 3)
                    .offset(
                        x: message.senderId == viewModel.userId ? 8 : -8,
                        y: 8
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .scale(scale: 0.1).combined(with: .opacity)
                    ))
            }
        }
    }
    
    private func shouldShowDate(current: Message, previous: Message?) -> Bool {
        guard let previous = previous else { return true }
        guard let currentDate = current.createdAt,
              let previousDate = previous.createdAt else {
            return true
        }
        
        return !Calendar.current.isDate(
            currentDate,
            inSameDayAs: previousDate
        )
    }
    
    @ViewBuilder
    private func dateSeparator(for message: Message) -> some View {
        if let date = message.createdAt {
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 1)
                
                Text(dayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func removeFriend() {
        guard let partnerId = viewModel.partner?.uid else { return }
        guard !isProcessing else { return }

        isProcessing = true
        
        UserRelationService.shared.removeFriend(partnerId: partnerId) { success in
            DispatchQueue.main.async {
                isProcessing = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func blockUser() {
        guard let partnerId = viewModel.partner?.uid else { return }
        
        isProcessing = true
        
        UserRelationService.shared.blockUser(targetUserId: partnerId) { success in
            DispatchQueue.main.async {
                isProcessing = false
                
                if success {
                    viewModel.shouldDismiss = true
                    viewModel.cleanupAfterBlock()
                }
            }
        }
    }
    
    private func sendOrCancelRequest() {
        guard let partnerId = viewModel.partner?.uid else { return }
        
        if relationManager.isRequestSent(to: partnerId) {
            UserRelationService.shared.cancelFriendRequest(to: partnerId) { _ in }
        } else {
            UserRelationService.shared.sendFriendRequest(to: partnerId) { _ in }
        }
    }
    
    func acceptRequest() {
        guard let partnerId = viewModel.partner?.uid,
              let requestId = relationManager.requestId(from: partnerId) else { return }
        
        let data: [String: Any] = [
            "partnerId": partnerId,
            "requestId": requestId
        ]
        
        Functions.functions(region: "asia-southeast1")
            .httpsCallable("acceptFriendRequest")
            .call(data) { result, error in
                
                if let error = error {
                    print("Accept error:", error.localizedDescription)
                    return
                }
            }
    }
    
    private func declineRequest() {
        guard let partnerId = viewModel.partner?.uid,
              let requestId = relationManager.requestId(from: partnerId) else { return }
        
        UserRelationService.shared.declineFriendRequest(
            requestId: requestId
        ) { _ in }
    }
    
    private func messagePosition(
        current: Message,
        previous: Message?,
        next: Message?
    ) -> MessagePosition {
        
        func isSameGroup(_ m1: Message?, _ m2: Message?) -> Bool {
            guard let m1 = m1, let m2 = m2 else { return false }
            
            guard m1.senderId == m2.senderId,
                  let d1 = m1.createdAt,
                  let d2 = m2.createdAt else {
                return false
            }
            
            return abs(d1.timeIntervalSince(d2)) < 60
        }
        
        let isPrevSame = isSameGroup(previous, current)
        let isNextSame = isSameGroup(current, next)
        
        switch (isPrevSame, isNextSame) {
        case (false, false): return .single
        case (false, true): return .top
        case (true, true): return .middle
        case (true, false): return .bottom
        }
    }
    
    private func topSpacing(for position: MessagePosition) -> CGFloat {
        switch position {
        case .top, .single:
            return 10
        case .middle, .bottom:
            return 2
        }
    }
}

struct MessageRow: View {
    let message: Message
    let isCurrentUser: Bool
    let partner: AppUser?
    let timeFormatter: DateFormatter
    let showAvatar: Bool
    let position: MessagePosition
    
    let onTapAvatar: (AppUser) -> Void
    let onLongPress: (Message) -> Void
    let onTapReaction: (Message) -> Void
    
    var isAI: Bool {
        message.senderId == "AI"
    }
        
    var body: some View {
        VStack(spacing: 4) {
            
            HStack(alignment: .bottom, spacing: 8) {
                
                if isCurrentUser && !isAI {
                    Spacer()
                    bubble
                } else {
                    Group {
                    if let partner = partner, showAvatar {
                        AsyncImage(url: URL(string: partner.avatar ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTapAvatar(partner)
                        }
                    } else {
                        Color.clear
                            .frame(width: 38)
                    }
                }
                    bubble
                    Spacer()
                }
            }
            
            HStack {
                if isCurrentUser { Spacer() }
                
                if let date = message.createdAt,
                   position == .bottom || position == .single {
                    
                    Text(timeFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if !isCurrentUser { Spacer() }
            }
        }
    }
    
    private var bubble: some View {
        ZStack(
            alignment: isCurrentUser ? .bottomTrailing : .bottomLeading
        ) {
            Text(message.text)
                .foregroundColor(isCurrentUser ? .white : .primary)
                .padding()
                .background(isCurrentUser ? Color.pink : Color(.systemGray5))
                .clipShape(bubbleShape)
                .onLongPressGesture {
                    if !isCurrentUser {
                        onLongPress(message)
                    }
                }
            
            if let reaction = message.reaction {
                Text(reaction)
                    .font(.caption)
                    .padding(6)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
                    .shadow(radius: 3)
                    .offset(x: isCurrentUser ? 8 : -8, y: 8)
                    .onTapGesture {
                        if !isCurrentUser {
                            onTapReaction(message)
                        }
                    }
            }
        }
    }
    
    private var bubbleShape: some Shape {
        let radius: CGFloat = 20
        
        return UnevenRoundedRectangle(
            topLeadingRadius: isCurrentUser ? radius : (position == .top || position == .single ? radius : 6),
            bottomLeadingRadius: isCurrentUser ? radius : (position == .bottom || position == .single ? radius : 6),
            bottomTrailingRadius: isCurrentUser ? (position == .bottom || position == .single ? radius : 6) : radius,
            topTrailingRadius: isCurrentUser ? (position == .top || position == .single ? radius : 6) : radius
        )
    }
}
