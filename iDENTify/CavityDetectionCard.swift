//
//  CavityDetectionCard.swift
//  iDENTify
//
//  Created by AI Assistant on $(date)
//  Copyright © 2024 iDENTify. All rights reserved.
//

import SwiftUI

/// Reusable card component for displaying individual cavity detection results
struct CavityDetectionCard: View {
    let cavity: CavityDetection
    let index: Int
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main card content
            HStack(spacing: 12) {
                // Severity indicator
                severityIndicator
                
                // Main content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cavity #\(index)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(cavity.severity.displayName)
                        .font(.subheadline)
                        .foregroundColor(severityColor(cavity.severity))
                    
                    Text("Confidence: \(Int(cavity.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Expanded details
            if isExpanded {
                expandedDetails
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Severity Indicator
    
    private var severityIndicator: some View {
        Circle()
            .fill(severityColor(cavity.severity))
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
    
    // MARK: - Expanded Details
    
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            // Location information
            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("X: \(Int(cavity.boundingBox.x * 100))%, Y: \(Int(cavity.boundingBox.y * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Size: \(Int(cavity.boundingBox.width * 100))% × \(Int(cavity.boundingBox.height * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Technical details
            VStack(alignment: .leading, spacing: 4) {
                Text("Technical Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Class ID: \(cavity.classId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Model: \(cavity.metadata.modelVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if cavity.metadata.processingTimeMs > 0 {
                    Text("Processing Time: \(String(format: "%.1f", cavity.metadata.processingTimeMs))ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Severity badge
            HStack {
                Text(cavity.severity.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor(cavity.severity))
                    .cornerRadius(6)
                
                Spacer()
                
                // Confidence bar
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(confidenceColor(cavity.confidence))
                                .frame(width: geometry.size.width * cavity.confidence, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(width: 60, height: 4)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Helper Functions
    
    private func severityColor(_ severity: CavitySeverity) -> Color {
        switch severity {
        case .mild:
            return .yellow
        case .moderate:
            return .orange
        case .severe:
            return .red
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

struct CavityDetectionCard_Previews: PreviewProvider {
    static var previews: some View {
        let mockBoundingBox = BoundingBox(x: 0.3, y: 0.4, width: 0.2, height: 0.15)
        let mockCavity = CavityDetection(
            boundingBox: mockBoundingBox,
            confidence: 0.85,
            severity: .moderate
        )
        
        VStack(spacing: 16) {
            CavityDetectionCard(cavity: mockCavity, index: 1)
            
            CavityDetectionCard(cavity: CavityDetection(
                boundingBox: BoundingBox(x: 0.6, y: 0.2, width: 0.15, height: 0.1),
                confidence: 0.92,
                severity: .severe
            ), index: 2)
            
            CavityDetectionCard(cavity: CavityDetection(
                boundingBox: BoundingBox(x: 0.1, y: 0.7, width: 0.25, height: 0.2),
                confidence: 0.65,
                severity: .mild
            ), index: 3)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
