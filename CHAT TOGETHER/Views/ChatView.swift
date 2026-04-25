import SwiftUI
import Kingfisher

struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var relationManager: RelationManager
    @EnvironmentObject var currentUserManager: CurrentUserManager
    @StateObject private var viewModel: ChatViewModel
    @State private var showLeaveAlert = false
    @State private var showProfile = false
    @State private var showMoreSheet = false
    @State private var showReportView = false
    @State private var showBlockAlert = false
    @State private var selectedUser: AppUser?
    @State private var showMentionList = false
    @State private var mentionQuery = ""
    @State private var isProcessing = false
    @State private var isProcessing111 = false
    @State private var replyingTo: Message?
    @State private var showMessageMenu = false
    @State private var scrollToMessageId: String?
    @State private var highlightedMessageId: String?
    @State private var selectedMessageFrame: CGRect = .zero
    @Namespace private var animation
    @State private var showOverlay = false
    
    init(room: ChatRoom, currentUserManager: CurrentUserManager) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room, currentUserManager: currentUserManager))
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
            }
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    
                    if showMentionList {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                insertMention("Tomi")
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.pink)
                                        .frame(width: 30, height: 30)
                                        .overlay(Text("T").foregroundColor(.white))
                                    
                                    Text("Tomi")
                                    Spacer()
                                }
                                .padding(8)
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 3)
                        .padding(.horizontal)
                    }
                    
                    inputSection
                }
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
            }
            .onAppear {
                viewModel.messages = []
                viewModel.fetchPartner()
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
                
                Button("Unfriend", role: .destructive) {
                    removeFriend()
                }
                
            } message: {
                Text("Would you like to unfriend? This can't be undone.")
            }
            .alert("You are no longer friends.", isPresented: $viewModel.showUnfriendAlert) {
                Button("OK") {
                    dismiss()
                }
            }
            .alert("Block User?", isPresented: $showBlockAlert) {
                
                Button("Cancel", role: .cancel) { }
                
                Button("Block", role: .destructive) {
                    blockUser()
                }
                
            } message: {
                Text("You will not be matched with this person again. This action cannot be undone. Are you sure you want to continue?")
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
            .overlay {
                if let message = selectedMessage, showOverlay {
                    ZStack {

                        // 🔥 BACKGROUND MỜ MẠNH
                        Color.black.opacity(0.9)
                            .ignoresSafeArea()
                            .onTapGesture { closeOverlay() }
                            .transition(.opacity)

                        // 🔥 CONTENT BÁM THEO BUBBLE
                        overlayContent(message: message)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showOverlay)
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
                
                if viewModel.room.type == .friend {
                    Button("Unfriend", role: .destructive) {
                        showRemoveFriendAlert = true
                    }
                }
                
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
                .fontWeight(.semibold)
                .foregroundColor(viewModel.room.type == .random ? .red : .primary)
            }
            
            // Avatar + name
            if let partner = viewModel.partner {
                Button {
                    print("Tapped avatar, partner:", viewModel.partner?.fullname ?? "nil")
                    selectedUser = viewModel.partner
                } label: {
                    HStack(spacing: 10) {
                        
                        KFImage(URL(string: partner.avatar ?? ""))
                            .placeholder {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            .retry(maxCount: 2, interval: .seconds(1))
                            .cacheOriginalImage(true)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        
                        Text(partner.fullname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
            
            // 🔥 FRIEND ACTION
            if viewModel.room.type == .random {
                if let partnerId = viewModel.partner?.uid {
                    
                    if relationManager.isFriend(with: partnerId) {
                        
                        Button {
                            showRemoveFriendAlert = true
                        } label: {
                            if isProcessing111 {
                                ProgressView()
                            } else {
                                Image(systemName: "person.fill.checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(isProcessing111)
                        
                    } else if relationManager.didReceiveRequest(from: partnerId) {
                        
                        HStack(spacing: 15) {
                            
                            Button {
                                acceptRequest()
                            } label: {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green.opacity(0.9))
                            }
                            
                            Button {
                                declineRequest()
                            } label: {
                                Image(systemName: "xmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red.opacity(0.9))
                            }
                        }
                        
                    } else {
                        
                        Button {
                            sendOrCancelRequest()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    relationManager.isRequestSent(to: partnerId)
                                    ? .gray
                                    : .green.opacity(0.9)
                                )
                        }
                    }
                }
            }
            
            // More button
            Button {
                showMoreSheet = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var messageSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    
                    ForEach(Array(messageItems.reversed())) { item in
                        messageRow(item)
                            .id(item.id)
                            .scaleEffect(x: 1, y: -1)
                    }
                }
                .padding()
            }
            .scaleEffect(x: 1, y: -1)
            .onChange(of: viewModel.messages.count) { _ in
                guard let lastId = viewModel.messages.last?.id else { return }
                
                DispatchQueue.main.async {
                    withTransaction(Transaction(animation: nil)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToMessageId) { id in
                if let id {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
    
    private var inputSection: some View {
        let isEmpty = viewModel.messageText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        
        return VStack(spacing: 6) {
            
            // 🔥 REPLY UI
            if let reply = replyingTo {
                HStack {
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(reply.text)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        replyingTo = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // 🔥 INPUT
            HStack(spacing: 8) {
                TextField("message... (type @Tomi to ask Tomi)", text: $viewModel.messageText)
                    .textFieldStyle(.plain) // 🔥 bỏ RoundedBorder cho đẹp hơn
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.send)
                    .onChange(of: viewModel.messageText) { text in
                        handleMention(text)
                    }
                    .onSubmit {
                        if !isEmpty {
                            sendMessageWithReply()
                        }
                    }
                
                Button {
                    sendMessageWithReply()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(isEmpty ? .gray : .white)
                        .padding(10)
                        .background(isEmpty ? Color.gray.opacity(0.3) : Color.pink)
                        .clipShape(Circle())
                }
                .disabled(isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
    
    private var messageItems: [MessageItemData] {
        let messages = viewModel.messages
        
        return messages.indices.map { index in
            MessageItemData(
                id: messages[index].id,
                message: messages[index],
                previous: index > 0 ? messages[index - 1] : nil,
                next: index < messages.count - 1 ? messages[index + 1] : nil
            )
        }
    }
    
    private func sendMessageWithReply() {
        viewModel.sendMessage(replyTo: replyingTo)
        replyingTo = nil
    }
    
    private func closeOverlay() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showOverlay = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedMessage = nil
        }
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
    private func messageRow(_ item: MessageItemData) -> some View {
        
        MessageItemView(
            message: item.message,
            previous: item.previous,
            next: item.next,
            viewModel: viewModel,
            timeFormatter: timeFormatter,
            onTapAvatar: { selectedUser = $0 },
            namespace: animation,
            onLongPress: { msg, frame in
                selectedMessage = msg
                selectedMessageFrame = frame
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showOverlay = true
                }
            },
            onTapReaction: {
                viewModel.removeReaction(messageId: $0.id)
            },
            onTapReply: { msg in
                if let targetId = msg.replyToMessageId {
                    scrollToMessageId = targetId
                }
            },
            isHighlighted: highlightedMessageId == item.message.id
        )
    }
    
    @ViewBuilder
    private func overlayContent(message: Message) -> some View {
        
        let bubbleWidth: CGFloat = 260
        
        VStack(spacing: 5) {
            
            // 🔥 ACTION BAR (reaction | reply)
            HStack {
                HStack(spacing: 10) {
                    ForEach(reactions, id: \.self) { emoji in
                        Text(emoji)
                            .font(.largeTitle)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleReactionTap(emoji, for: message)
                                closeOverlay()
                            }
                    }
                }
                Spacer()
                
                Divider()
                    .frame(height: 20)
                
                Spacer()
                
                Button {
                    replyingTo = message
                    if message.isAI == true {
                            if !viewModel.messageText.contains("@Tomi") {
                                viewModel.messageText = "@Tomi " + viewModel.messageText
                            }
                        }
                    closeOverlay()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left")
                        Text("Reply")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            // 💬 BUBBLE
            MessageRow(
                message: message,
                isCurrentUser: message.senderId == viewModel.userId,
                partner: viewModel.partner,
                timeFormatter: timeFormatter,
                showAvatar: false,
                position: .single,
                onTapAvatar: { _ in },
                namespace: animation,
                isOverlay: true,
                isDimmed: false,
                onLongPress: { _, _ in },
                onTapReaction: { _ in },
                onTapReply: { _ in },
                isHighlighted: false
            )
            .frame(width: bubbleWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .position(x: UIScreen.main.bounds.width / 2,
                  y: selectedMessageFrame.minY - 65)
    }
    
    @ViewBuilder
    private func dateSeparator(for message: Message) -> some View {
        if let date = message.createdAt {
                Text(dayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.65))
                    .padding(.horizontal, 8)
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
                if !success {
                    print("Remove friend failed")
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
                
        // 🚀 CASE 1: CANCEL REQUEST
        if relationManager.isRequestSent(to: partnerId) {
            
            // optimistic
            relationManager.cancelRequestLocally(to: partnerId)
            
            UserRelationService.shared.cancelFriendRequest(to: partnerId) { success in
                DispatchQueue.main.async {
                    
                    if !success {
                        // rollback
                        relationManager.rollbackCancelRequest(to: partnerId)
                    }
                }
            }
            
        } else {
            
            // 🚀 CASE 2: SEND REQUEST
            
            // optimistic
            relationManager.sendRequestLocally(to: partnerId)
            
            UserRelationService.shared.sendFriendRequest(to: partnerId) { success in
                DispatchQueue.main.async {
                    
                    if !success {
                        // rollback
                        relationManager.rollbackSendRequest(to: partnerId)
                    }
                }
            }
        }
    }
    
    func acceptRequest() {
        guard let partnerId = viewModel.partner?.uid,
              let requestId = relationManager.requestId(from: partnerId) else { return }
                
        // 🚀 1. UPDATE UI NGAY (optimistic)
        relationManager.markAsFriendLocally(with: partnerId)
        
        // 🚀 2. Gọi backend
        UserRelationService.shared.acceptFriendRequest(
            requestId: requestId,
            partnerId: partnerId
        ) { success in
            
            DispatchQueue.main.async {
                if !success {
                    // ❗ rollback nếu fail
                    relationManager.rollbackFriendState(with: partnerId)
                }
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
            return 0
        }
    }
}

struct MessageItemData: Identifiable {
    let id: String
    let message: Message
    let previous: Message?
    let next: Message?
}

struct MessageItemView: View {
    let message: Message
    let previous: Message?
    let next: Message?
    
    let viewModel: ChatViewModel
    let timeFormatter: DateFormatter
    
    let onTapAvatar: (AppUser) -> Void
    let namespace: Namespace.ID
    let onLongPress: (Message, CGRect) -> Void
    let onTapReaction: (Message) -> Void
    let onTapReply: (Message) -> Void
    
    let isHighlighted: Bool
    
    var body: some View {
        let position = messagePosition()
        let showAvatar = (position == .bottom || position == .single)
        
        VStack(spacing: 0) {
            
            if shouldShowDate() {
                dateSeparator()
            }
            
            MessageRow(
                message: message,
                isCurrentUser: message.senderId == viewModel.userId,
                partner: viewModel.partner,
                timeFormatter: timeFormatter,
                showAvatar: showAvatar,
                position: position,
                onTapAvatar: onTapAvatar,
                namespace: namespace,
                isOverlay: false,
                isDimmed: false,
                onLongPress: onLongPress,
                onTapReaction: onTapReaction,
                onTapReply: onTapReply,
                isHighlighted: isHighlighted
            )
            .padding(.top, topSpacing(for: position))
        }
    }
    
    // MARK: - Helpers
    
    private func messagePosition() -> MessagePosition {
        func isSameGroup(_ m1: Message?, _ m2: Message?) -> Bool {
            guard let m1 = m1, let m2 = m2 else { return false }
            guard m1.senderId == m2.senderId,
                  let d1 = m1.createdAt,
                  let d2 = m2.createdAt else { return false }
            return abs(d1.timeIntervalSince(d2)) < 60
        }
        
        let isPrevSame = isSameGroup(previous, message)
        let isNextSame = isSameGroup(message, next)
        
        switch (isPrevSame, isNextSame) {
        case (false, false): return .single
        case (false, true): return .top
        case (true, true): return .middle
        case (true, false): return .bottom
        }
    }
    
    private func shouldShowDate() -> Bool {
        guard let prev = previous else { return true }
        guard let c = message.createdAt,
              let p = prev.createdAt else { return true }
        return !Calendar.current.isDate(c, inSameDayAs: p)
    }
    
    @ViewBuilder
    private func dateSeparator() -> some View {
        if let date = message.createdAt {
            HStack {
                Rectangle().fill(Color.gray.opacity(0.4)).frame(height: 1)
                Text(timeFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.gray)
                Rectangle().fill(Color.gray.opacity(0.4)).frame(height: 1)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func topSpacing(for position: MessagePosition) -> CGFloat {
        switch position {
        case .top, .single: return 10
        case .middle, .bottom: return 2
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
    let namespace: Namespace.ID
    let isOverlay: Bool
    let isDimmed: Bool
    let onLongPress: (Message, CGRect) -> Void
    let onTapReaction: (Message) -> Void
    let onTapReply: (Message) -> Void
    let isHighlighted: Bool
    
    var isAI: Bool {
        message.isAI == true
    }
    
    @State private var currentFrame: CGRect = .zero
    
    var body: some View {
        VStack(spacing: 4) {
            
            HStack(alignment: .bottom, spacing: 8) {
                
                if isCurrentUser && !isAI {
                    Spacer()
                    bubble
                } else {
                    Group {
                        if showAvatar {
                            if isAI {
                                Image("logo1")
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else if let partner = partner {
                                KFImage(URL(string: partner.avatar ?? ""))
                                    .placeholder {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    .retry(maxCount: 2, interval: .seconds(1))
                                    .cacheOriginalImage(true)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 38, height: 38)
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        onTapAvatar(partner)
                                    }
                            } else {
                                Circle().fill(Color.gray.opacity(0.2))
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 38, height: 38)

                    bubble
                    Spacer()
                }
            }
            
            HStack {
                if isCurrentUser { Spacer() }
                
                if !isOverlay,
                   let date = message.createdAt,
                   position == .bottom || position == .single {
                    
                    Text(timeFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if !isCurrentUser { Spacer() }
            }
        }
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: MessageFrameKey.self,
                        value: geo.frame(in: .global)
                    )
            }
        )
        .onPreferenceChange(MessageFrameKey.self) { value in
            self.currentFrame = value
        }
        .onLongPressGesture {
            if !isCurrentUser {
                onLongPress(message, currentFrame)
            }
        }
    }
    
    private var bubble: some View {
        VStack(
            alignment: isCurrentUser ? .trailing : .leading,
            spacing: 4
        ) {
            
            if !isOverlay, let reply = message.replyPreview {
                    Text(reply)
                        .foregroundColor(.primary.opacity(0.6))
                        .lineLimit(2)
                        .padding(15)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture {
                            onTapReply(message)
                        }
            }
            
            // 💬 BUBBLE
                Text(message.text)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .padding(15)
                    .background(isCurrentUser ? Color.pink : Color(.systemGray5))
                    .clipShape(bubbleShape)
                    .matchedGeometryEffect(
                        id: message.id,
                        in: namespace,
                        isSource: !isOverlay
                    )
        }
        .overlay(alignment: isCurrentUser ? .bottomTrailing : .bottomLeading) {
                if let reaction = message.reaction, !isOverlay {
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
        .contentShape(Rectangle())
        .background(
            isHighlighted ? Color.yellow.opacity(0.3) : Color.clear
        )
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

struct MessageFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
