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
    @FocusState private var isInputFocused: Bool
    @State private var showCopiedToast = false
    @State private var isAITyping = false
    
    init(room: ChatRoom, currentUserManager: CurrentUserManager) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(room: room, currentUserManager: currentUserManager))
    }
    
    // MARK: - Reactions
    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "😡"]
    
    @State private var selectedMessage: Message?
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
                    if isAITyping {
                        HStack(spacing: 4) {
                            Text("Tomi is typing")
                                .font(.footnote)
                                .foregroundColor(.primary)
                            
                            TypingDotsView()
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    if showMentionList {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                insertMention("Tomi")
                            } label: {
                                HStack {
                                    Image("logo1")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                    Text("Tomi")
                                    Spacer()
                                }
                                .padding(8)
                            }
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 5)
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
            .onReceive(viewModel.$isAITyping) { value in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAITyping = value
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
            .overlay {
                if showCopiedToast {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Copied")
                        }
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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
                    Button("Unfriend") {
                        showRemoveFriendAlert = true
                    }
                }
                
                Button("Block") {
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
                        if let avatar = partner.avatar, let url = URL(string: avatar) {
                            KFImage(url)
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
                        } else {
                            ZStack {
                                Circle().fill(Color.gray.opacity(0.2))
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 36, height: 36)
                        }
                        
                        Text(partner.fullname)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
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
                        Text(replyingLabel(for: reply))
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
                .padding(.horizontal)
            }
            
            // 🔥 INPUT
            HStack(spacing: 8) {
                TextField("message... (type @Tomi to ask Tomi)", text: $viewModel.messageText)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
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
    
    private func replyingLabel(for message: Message) -> String {
        // AI
        if message.isAI == true {
            return "Replying to Tomi"
        }
        
        // Myself
        if message.senderId == viewModel.userId {
            return "Replying to yourself"
        }
        
        // Partner
        if let partner = viewModel.partner {
            return "Replying to \(partner.fullname)"
        }
        
        return "Replying"
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
        guard let userId = viewModel.userId else { return }
        
        let current = message.reactions?[userId]
        
        if current == emoji {
            viewModel.removeReaction(messageId: message.id)
        } else {
            viewModel.updateReaction(
                messageId: message.id,
                userId: userId,
                emoji: emoji
            )
        }
    }
    
    private func insertMention(_ name: String) {
        guard let range = viewModel.messageText.range(of: "@\\w*$", options: .regularExpression) else {
            return
        }
        
        viewModel.messageText.replaceSubrange(range, with: "@\(name) ")
        showMentionList = false
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
        
        ZStack {
            VStack(spacing: 5) {
                
                // 🔥 ACTION BAR (reaction | reply)
                HStack {
                    HStack(spacing: 10) {
                        let currentReaction = message.reactions?[viewModel.userId ?? ""]
                        ForEach(reactions, id: \.self) { emoji in
                            VStack(spacing: 1) {
                                
                                Text(emoji)
                                    .font(.largeTitle)
                                
                                if currentReaction == emoji {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 4, height: 4)
                                        .transition(.scale)
                                } else {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
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
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                        
                        replyingTo = message
                        if message.isAI == true {
                            if !viewModel.messageText.contains("@Tomi") {
                                viewModel.messageText = "@Tomi " + viewModel.messageText
                            }
                        }
                        closeOverlay()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isInputFocused = true
                        }
                        
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
                      y: selectedMessageFrame.midY - 80)
            
            VStack(spacing: 8) {
                Spacer()
                
                if let date = message.createdAt {
                        HStack {
                            if message.senderId == viewModel.userId && message.isAI != true {
                                Spacer()
                            }
                            
                            Text(overlayFormattedDate(date))
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.7))
                            
                            if message.senderId != viewModel.userId || message.isAI == true {
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    UIPasteboard.general.string = message.text
                    showCopiedToastWithAnimation()
                    closeOverlay()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func showCopiedToastWithAnimation() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                showCopiedToast = false
            }
        }
    }
    
    private func overlayFormattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let formatterTime = DateFormatter()
        formatterTime.locale = Locale.current
        formatterTime.setLocalizedDateFormatFromTemplate("j:mm")
        let time = formatterTime.string(from: date)
        
        if calendar.isDateInToday(date) {
            return time
        }
        
        if calendar.isDateInYesterday(date) {
            return "YESTERDAY \(time)"
        }
        
        if let days = calendar.dateComponents([.day], from: date, to: now).day,
           days < 7 {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            let day = formatter.string(from: date).uppercased()
            return "\(day) \(time)"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let day = formatter.string(from: date).uppercased()
        
        return "\(day) AT \(time)"
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
        guard let currentDate = message.createdAt,
              let prevDate = prev.createdAt else { return true }
        
        let diff = currentDate.timeIntervalSince(prevDate)
        return diff >= 60 * 60
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter.string(from: date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let time = timeString(date)
        
        if calendar.isDateInToday(date) {
            return time
        }
        
        if calendar.isDateInYesterday(date) {
            return "YESTERDAY \(time)"
        }
        
        if let days = calendar.dateComponents([.day], from: date, to: now).day,
           days < 7 {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            let day = formatter.string(from: date).uppercased()
            return "\(day) \(time)"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let day = formatter.string(from: date).uppercased()
        
        return "\(day) AT \(time)"
    }
    
    @ViewBuilder
    private func dateSeparator() -> some View {
        if let date = message.createdAt {
            HStack {
                Text(formattedDate(date))
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.75))
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
                            } else if let partner = partner, let avatar = partner.avatar, let url = URL(string: avatar) {
                                KFImage(url)
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
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.2))
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 38, height: 38)
                                .onTapGesture {
                                    if let partner = partner {
                                        onTapAvatar(partner)
                                    }
                                }
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
            if let display = reactionDisplay(for: message), !isOverlay {
                
                HStack(spacing: 4) {
                    
                    ForEach(display.emojis.prefix(2), id: \.self) { emoji in
                        Text(emoji)
                    }
                    
                    if display.count > 1 {
                        Text("\(display.count)")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .padding(6)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .shadow(radius: 3)
                .offset(x: isCurrentUser ? 8 : -8, y: 8)
                .onTapGesture {
                    onTapReaction(message)
                }
            }
        }
        .onLongPressGesture {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress(message, currentFrame)
        }
        .background(
            isHighlighted ? Color.yellow.opacity(0.3) : Color.clear
        )
    }
    
    private func reactionDisplay(for message: Message) -> (emojis: [String], count: Int)? {
        guard let reactions = message.reactions else { return nil }
        
        let values = Array(reactions.values)
        
        if values.isEmpty {
            return nil
        }
        
        let unique = Array(Set(values))
        
        if unique.count == 1 {
            return (emojis: [unique[0]], count: values.count)
        } else {
            return (emojis: values, count: values.count)
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

struct MessageFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct TypingDotsView: View {
    
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 4) {
            Dot(delay: 0.0, animate: animate)
            Dot(delay: 0.15, animate: animate)
            Dot(delay: 0.3, animate: animate)
        }
        .onAppear {
            animate = true
        }
    }
}

private struct Dot: View {
    let delay: Double
    let animate: Bool
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0.3
    
    var body: some View {
        Circle()
            .frame(width: 5, height: 5)
            .offset(y: offset + 2.5)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(delay)
                ) {
                    offset = -5
                    opacity = 1
                }
            }
    }
}
