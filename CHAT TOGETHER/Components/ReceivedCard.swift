import SwiftUI
import Kingfisher

struct ReceivedCard: View {
    let user: AppUser
    let acceptAction: () -> Void
    let rejectAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                
                KFImage(URL(string: user.avatar ?? ""))
                    .placeholder {
                        ProgressView()
                            .controlSize(.small)
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage(true)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(3/4, contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                
                HStack(spacing: 10) {
                    Button(action: rejectAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                            .padding(10)
                            .background(.black.opacity(0.4))
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Button(action: acceptAction) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                            .padding(10)
                            .background(.black.opacity(0.4))
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(10)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            }
            
            // Name Section
            VStack(alignment: .leading) {
                Text(user.fullname)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
