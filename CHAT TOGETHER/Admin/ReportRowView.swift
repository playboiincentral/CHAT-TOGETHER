//
//  ReportRowView.swift
//  CHAT TOGETHER
//
//  Created by Playboi In Central on 4/16/26.
//

import SwiftUI

struct ReportRowView: View {
    var report: ChatReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Text(report.reasons.first?.rawValue.capitalized ?? "Report")
                    .font(.headline)
                
                Spacer()
                
                Text(report.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Text("Reported user: \(report.reportedUserId)")
                .font(.caption)
                .foregroundColor(.gray)
            
            if let desc = report.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
    
    var statusColor: Color {
        switch report.status {
        case .pending:
            return .orange
        case .resolved:
            return .green
        case .rejected:
            return .gray
        }
    }
}
