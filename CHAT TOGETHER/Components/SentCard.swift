import SwiftUI
import Kingfisher

struct SentCard: View {
    let user: AppUser
    let cancelAction: () -> Void
    
    @State private var isCancel = false
    
    var body: some View {
            ZStack {
                // IMAGE
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
                        .frame(height: 220)
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
                
                // 🔥 GRADIENT
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                Text(user.fullname)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .lineLimit(1)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                
                // ❌ BUTTON (top right)
                VStack {
                    HStack {
                        Spacer()
                        
                        Button {
                            isCancel = true
                            cancelAction()
                        } label: {
                            if isCancel {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .disabled(isCancel)
                    }
                    Spacer()
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
