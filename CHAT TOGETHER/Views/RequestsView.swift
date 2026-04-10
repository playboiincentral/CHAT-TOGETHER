import SwiftUI

enum RequestTab: CaseIterable {
    case received
    case sent
    
    func title(receivedCount: Int) -> String {
        switch self {
        case .received:
            return "\(receivedCount) " + (receivedCount == 1 ? "Request" : "Requests")
        case .sent:
            return "Sent"
        }
    }
}

struct RequestsView: View {
    
    @EnvironmentObject var relationManager: RelationManager
    @State private var selectedTab: RequestTab = .received
        
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            VStack {
                
                // Segmented Control
                Picker("", selection: $selectedTab) {
                    ForEach(RequestTab.allCases, id: \.self) { tab in
                        Text(
                            tab.title(
                                receivedCount: relationManager.receivedRequests.count,
                            )
                        )
                        .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                ScrollView {
                    VStack {
                        if selectedTab == .received {
                            receivedView
                        } else {
                            sentView
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadUsers()
            }
            .onChange(of: relationManager.receivedRequests) { _ in
                loadUsers()
            }
            .onChange(of: relationManager.sentRequests) { _ in
                loadUsers()
            }
        }
    }
    @ViewBuilder
    private var receivedView: some View {
        if !relationManager.receivedRequests.isEmpty {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(relationManager.receivedRequests.keys), id: \.self) { userId in
                    
                    if let user = relationManager.users[userId] {
                        ReceivedCard(user: user) {
                            accept(userId: userId)
                        } rejectAction: {
                            reject(userId: userId)
                        }
                    } else {
                        placeholderCard
                    }
                }
            }
            .padding(.horizontal)
        } else {
            Text("No requests")
                .foregroundColor(.gray)
                .padding(.top, 40)
        }
    }
    
    @ViewBuilder
    private var sentView: some View {
        if !relationManager.sentRequests.isEmpty {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(relationManager.sentRequests), id: \.self) { userId in
                    
                    if let user = relationManager.users[userId] {
                        SentCard(user: user) {
                            cancelRequest(userId: userId)
                        }
                    } else {
                        placeholderCard
                    }
                }
            }
            .padding(.horizontal)
        } else {
            Text("No sent requests")
                .foregroundColor(.gray)
                .padding(.top, 40)
        }
    }
    
    private var placeholderCard: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 160)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 12)
                .padding(.horizontal, 20)
        }
    }
    
    private func loadUsers() {
        let allIds = Array(relationManager.receivedRequests.keys)
        + Array(relationManager.sentRequests)
        
        let uniqueIds = Array(Set(allIds))
        
        let idsToFetch = uniqueIds.filter { relationManager.users[$0] == nil }
        
        let chunks = idsToFetch.chunked(into: 10)
        
        for chunk in chunks {
            UserService.shared.fetchUsers(userIds: chunk) { fetchedUsers in
                DispatchQueue.main.async {
                    relationManager.mergeUsers(fetchedUsers)
                }
            }
        }
    }
}

extension RequestsView {
    
    func accept(userId: String) {
        guard let requestId = relationManager.requestId(from: userId) else { return }
        
        UserRelationService.shared.acceptFriendRequest(
            requestId: requestId,
            partnerId: userId
        ) { _ in }
    }
    
    func reject(userId: String) {
        guard let requestId = relationManager.requestId(from: userId) else { return }
        
        UserRelationService.shared.declineFriendRequest(
            requestId: requestId
        ) { _ in }
    }
    
    func cancelRequest(userId: String) {
        UserRelationService.shared.cancelFriendRequest(
            to: userId
        ) { _ in }
    }
    
    func showToast(_ message: String) {
        print(message)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    RequestsView()
}
