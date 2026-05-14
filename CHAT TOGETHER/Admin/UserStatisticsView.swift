import SwiftUI
import FirebaseFirestore

struct UserStatisticsView: View {
    
    enum StatisticsType {
        case gender
        case age
    }
    
    @State private var selectedType: StatisticsType = .gender
    
    @State private var totalUsers: Int = 0
    @State private var maleUsers: Int = 0
    @State private var femaleUsers: Int = 0
    
    @State private var age18To24: Int = 0
    @State private var age25To34: Int = 0
    @State private var age35To44: Int = 0
    @State private var age45To54: Int = 0
    @State private var age55To64: Int = 0
    @State private var age65Plus: Int = 0
    
    @EnvironmentObject private var vm: AuthViewModel
    
    private let db = Firestore.firestore()
    
    // MARK: - Gender Percent
    
    private var malePercent: Double {
        percent(maleUsers)
    }
    
    private var femalePercent: Double {
        percent(femaleUsers)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Total Users
                    
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .blue.opacity(0.5),
                                        .purple.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 14
                            )
                            .frame(width: 220, height: 220)
                        
                        VStack(spacing: 8) {
                            Text("Total Users")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("\(totalUsers)")
                                .font(.system(size: 42, weight: .bold))
                        }
                    }
                    
                    // MARK: - Tabs
                    
                    HStack(spacing: 12) {
                        
                        Button {
                            selectedType = .gender
                        } label: {
                            Text("Gender")
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    selectedType == .gender
                                    ? .white
                                    : .primary
                                )
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if selectedType == .gender {
                                            LinearGradient(
                                                colors: [
                                                    .blue.opacity(0.5),
                                                    .purple.opacity(0.5)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        } else {
                                            Color.gray.opacity(0.15)
                                        }
                                    }
                                )
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            selectedType = .age
                        } label: {
                            Text("Age")
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    selectedType == .age
                                    ? .white
                                    : .primary
                                )
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if selectedType == .age {
                                            LinearGradient(
                                                colors: [
                                                    .blue.opacity(0.5),
                                                    .purple.opacity(0.5)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        } else {
                                            Color.gray.opacity(0.15)
                                        }
                                    }
                                )
                                .clipShape(Capsule())
                        }
                    }
                    
                    // MARK: - Statistics
                    
                    VStack(spacing: 18) {
                        
                        if selectedType == .gender {
                            
                            statisticsBar(
                                title: "Female",
                                percent: femalePercent,
                                color: .pink
                            )
                            
                            statisticsBar(
                                title: "Male",
                                percent: malePercent,
                                color: .blue
                            )
                            
                        } else {
                            
                            statisticsBar(
                                title: "18-24",
                                percent: percent(age18To24),
                                color: .purple.opacity(0.6)
                            )
                            
                            statisticsBar(
                                title: "25-34",
                                percent: percent(age25To34),
                                color: .purple.opacity(0.6)
                            )
                            
                            statisticsBar(
                                title: "35-44",
                                percent: percent(age35To44),
                                color: .purple.opacity(0.6)
                            )
                            
                            statisticsBar(
                                title: "45-54",
                                percent: percent(age45To54),
                                color: .purple.opacity(0.6)
                            )
                            
                            statisticsBar(
                                title: "55-64",
                                percent: percent(age55To64),
                                color: .purple.opacity(0.6)
                            )
                            
                            statisticsBar(
                                title: "65+",
                                percent: percent(age65Plus),
                                color: .purple.opacity(0.6)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .task {
                await fetchUsersStatistics()
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        do {
                            try vm.signOut()
                        } catch {
                            print("Sign out error:", error.localizedDescription)
                        }
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics Bar
    
    @ViewBuilder
    private func statisticsBar(
        title: String,
        percent: Double,
        color: Color
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                Text(title)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "%.1f%%", percent * 100))
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .frame(
                            width: geo.size.width * percent,
                            height: 16
                        )
                }
            }
            .frame(height: 16)
        }
    }
    
    // MARK: - Percent
    
    private func percent(_ count: Int) -> Double {
        guard totalUsers > 0 else { return 0 }
        return Double(count) / Double(totalUsers)
    }
    
    // MARK: - Fetch Statistics
    
    private func fetchUsersStatistics() async {
        do {
            
            let snapshot = try await db.collection("users").getDocuments()
            
            let users = snapshot.documents.compactMap {
                try? $0.data(as: AppUser.self)
            }
            
            totalUsers = users.count
            
            maleUsers = users.filter {
                $0.gender == .male
            }.count
            
            femaleUsers = users.filter {
                $0.gender == .female
            }.count
            
            let calendar = Calendar.current
            let currentDate = Date()
            
            age18To24 = 0
            age25To34 = 0
            age35To44 = 0
            age45To54 = 0
            age55To64 = 0
            age65Plus = 0
            
            for user in users {
                
                guard let dob = user.dateOfBirth else {
                    continue
                }
                
                let age = calendar.dateComponents(
                    [.year],
                    from: dob,
                    to: currentDate
                ).year ?? 0
                
                switch age {
                    
                case 18...24:
                    age18To24 += 1
                    
                case 25...34:
                    age25To34 += 1
                    
                case 35...44:
                    age35To44 += 1
                    
                case 45...54:
                    age45To54 += 1
                    
                case 55...64:
                    age55To64 += 1
                    
                case 65...150:
                    age65Plus += 1
                    
                default:
                    break
                }
            }
            
        } catch {
            print("ERROR FETCH USER STATS: \(error.localizedDescription)")
        }
    }
}

#Preview {
    UserStatisticsView()
}
