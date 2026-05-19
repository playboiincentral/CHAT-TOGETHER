import SwiftUI
import Kingfisher

struct ReceivedCard: View {
    let user: AppUser
    let isAccepting: Bool
    let isRejecting: Bool
    let acceptAction: () -> Void
    let rejectAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .bottomLeading) {
                if let avatar = user.avatar, let url = URL(string: avatar) {
                    KFImage(url)
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
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.2))
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    }
                    .aspectRatio(3/4, contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 220)
                }
                
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Text(user.fullname)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .lineLimit(1)
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            HStack(spacing: 5) {
                Button {
                    rejectAction()
                } label: {
                    if isRejecting {
                        ProgressView()
                    } else {
                        Image(systemName: "xmark")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .disabled(isRejecting)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                
                Button {
                    acceptAction()
                } label: {
                    if isAccepting {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .disabled(isAccepting)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(Circle())
            }
            .padding(10)
        }
//        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
