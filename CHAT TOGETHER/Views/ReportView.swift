import SwiftUI
import FirebaseFirestore

struct ReportView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ReportViewModel()
    @State private var showToast = false
    @State private var showConfirmDialog = false
    @State private var isProcessing = false
    
    let roomId: String
    let reporterId: String
    let reportedUserId: String
    
    var body: some View {
        NavigationStack {
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
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConfirmDialog = true
                    } label: {
                        ZStack {
                            Text("Submit")
                                .foregroundStyle(viewModel.isValid ? .blue : .gray.opacity(0.5))
                                .opacity(viewModel.isSubmitting || isProcessing ? 0 : 1)
                            
                            ProgressView()
                                .opacity(viewModel.isSubmitting || isProcessing ? 1 : 0)
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting || isProcessing)
                }
            }
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        
                        ProgressView("Processing...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .overlay(alignment: .top) {
                if showToast {
                    Text("Report submitted.")
                        .font(.subheadline)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                listenUserDeletion()
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
            .confirmationDialog("", isPresented: $showConfirmDialog) {
                
                Button("Report & Block") {
                    submitReportAndBlock()
                }
                
                Button("Just Report") {
                    submitReportOnly()
                }
                
                Button("Cancel", role: .cancel) { }
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
    
    private func title(for reason: ReportReason) -> LocalizedStringKey {
        switch reason {
        case .harassment: return "report.harassment"
        case .sexualContent: return "report.sexualContent"
        case .hateSpeech: return "report.hateSpeech"
        case .spam: return "report.spam"
        case .discrimination: return "report.discrimination"
        case .violence: return "report.violence"
        case .scam: return "report.scam"
        case .other: return "report.other"
        }
    }
    
    private func submitReportOnly() {
        guard !viewModel.isSubmitting else { return }
        
        viewModel.submitReport(
            roomId: roomId,
            reporterId: reporterId,
            reportedUserId: reportedUserId
        )
    }
    
    private func submitReportAndBlock() {
        guard !viewModel.isSubmitting, !isProcessing else { return }
        
        isProcessing = true
        
        viewModel.submitReport(
            roomId: roomId,
            reporterId: reporterId,
            reportedUserId: reportedUserId
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            
            UserRelationService.shared.blockUser(targetUserId: reportedUserId) { success in
                DispatchQueue.main.async {
                    isProcessing = false
                    
                    if success {
                        NotificationCenter.default.post(name: .userBlocked, object: reportedUserId)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func listenUserDeletion() {
        Firestore.firestore()
            .collection("users")
            .document(reportedUserId)
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    print("Listen error:", error.localizedDescription)
                    return
                }
                
                if snapshot == nil || !(snapshot?.exists ?? false) {
                    dismiss()
                }
            }
    }
}
