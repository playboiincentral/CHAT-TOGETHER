import SwiftUI

struct ReportView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ReportViewModel()
    @State private var showToast = false
    
    let roomId: String
    let reporterId: String
    let reportedUserId: String
    
    var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Reasons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Report Type *")
                            .font(.headline)
                        
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            reasonRow(reason)
                        }
                    }
                    
                    // MARK: - Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.description)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // MARK: - Submit
                    Button {
                        guard !viewModel.isSubmitting else { return }
                        
                        viewModel.submitReport(
                            roomId: roomId,
                            reporterId: reporterId,
                            reportedUserId: reportedUserId
                        )
                    } label: {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView()
                            } else {
                                Text("Submit")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isValid ? Color.red : Color.gray)
                        .opacity(viewModel.isSubmitting ? 0.7 : 1)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if showToast {
                    Text("Report submitted")
                        .font(.subheadline)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: viewModel.isSuccess) { success in
                if success {
                    withAnimation {
                        showToast = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showToast = false
                        }
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }
    
    // MARK: - Row
    private func reasonRow(_ reason: ReportReason) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.toggleReason(reason)
            }
        } label: {
            HStack {
                Text(title(for: reason))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: viewModel.selectedReasons.contains(reason)
                      ? "checkmark.circle.fill"
                      : "circle")
                .foregroundColor(viewModel.selectedReasons.contains(reason) ? .red : .gray)
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
    }
    
    private func title(for reason: ReportReason) -> String {
        switch reason {
        case .harassment: return "Harassment"
        case .sexualContent: return "Sexual Content"
        case .hateSpeech: return "Hate Speech"
        case .spam: return "Spam"
        case .discrimination: return "Discrimination"
        case .violence: return "Violence"
        case .scam: return "Scam"
        case .other: return "Other"
        }
    }
}

#Preview {
    ReportView(roomId: "123", reporterId: "123", reportedUserId: "123")
}
