import SwiftUI

struct ReceivedCard: View {
    let user: AppUser
    let acceptAction: () -> Void
    let rejectAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) { // Chuyển nút sang góc để không che mặt
                
                AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                }
                // Thay vì frame cứng 220, ta dùng aspectRatio để tự co giãn theo chiều rộng
                .aspectRatio(3/4, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .contentShape(RoundedRectangle(cornerRadius: 20))
                
                // Buttons overlay: Thêm hiệu ứng đổ bóng để nổi bật trên ảnh
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
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullname)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Friend request")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
