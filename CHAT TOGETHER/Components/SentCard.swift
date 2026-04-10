import SwiftUI

struct SentCard: View {
    let user: AppUser
    let cancelAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                
                // Avatar
                AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.1)
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .aspectRatio(3/4, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 200) // Thấp hơn một chút so với card nhận được
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Nút Hủy (Cancel) - Nhìn nhẹ nhàng hơn
                Button(action: cancelAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.4))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(10)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullname)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Badge trạng thái nhỏ
                Text("Friend request sent")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
