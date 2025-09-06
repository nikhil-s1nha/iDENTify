//
//  ResultsView.swift
//  iDENTify
//
//  Created by AI Assistant on $(date)
//  Copyright © 2024 iDENTify. All rights reserved.
//

import SwiftUI

/// Comprehensive results screen for displaying cavity detection analysis results
struct ResultsView: View {
    @ObservedObject var cameraViewModel: CameraViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                headerSection
                
                // Image Display Section
                imageSection
                
                // Results Summary Section
                resultsSummarySection
                
                // Detailed Findings Section
                if let result = cameraViewModel.detectionResult, !result.cavities.isEmpty {
                    detailedFindingsSection(result: result)
                }
                
                // Recommendations Section
                recommendationsSection
                
                // Action Buttons Section
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    cameraViewModel.resetNavigation()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Analysis Complete")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your dental image has been analyzed using AI-powered cavity detection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analyzed Image")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let image = cameraViewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .overlay(
                        // Overlay bounding boxes if cavities are detected
                        cavityOverlayView(image: image)
                    )
            }
        }
    }
    
    // MARK: - Results Summary Section
    
    private var resultsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let result = cameraViewModel.detectionResult {
                HStack(spacing: 20) {
                    // Total Cavities
                    VStack {
                        Text("\(result.cavities.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(result.cavities.isEmpty ? .green : .orange)
                        Text("Cavities Found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Overall Confidence
                    VStack {
                        Text("\(Int(result.overallConfidence * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Urgency Level
                    VStack {
                        Text(result.summary.urgencyLevel.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(urgencyColor(result.summary.urgencyLevel))
                        Text("Priority")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Detailed Findings Section
    
    private func detailedFindingsSection(result: DetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Findings")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(result.cavitiesByConfidence.enumerated()), id: \.element.id) { index, cavity in
                    CavityDetectionCard(cavity: cavity, index: index + 1)
                }
            }
        }
    }
    
    // MARK: - Recommendations Section
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let result = cameraViewModel.detectionResult {
                VStack(alignment: .leading, spacing: 8) {
                    // Urgency Level Badge
                    HStack {
                        Image(systemName: urgencyIcon(result.summary.urgencyLevel))
                            .foregroundColor(urgencyColor(result.summary.urgencyLevel))
                        Text(result.summary.urgencyLevel.displayName)
                            .fontWeight(.semibold)
                            .foregroundColor(urgencyColor(result.summary.urgencyLevel))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(urgencyColor(result.summary.urgencyLevel).opacity(0.1))
                    .cornerRadius(8)
                    
                    // Observations
                    if let observations = result.summary.observations {
                        Text(observations)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Next Steps
                    nextStepsView(result: result)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                cameraViewModel.resetNavigation()
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Analyze Another Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: {
                // TODO: Implement save results functionality
                print("Save results tapped")
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Results")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func cavityOverlayView(image: UIImage) -> some View {
        GeometryReader { geometry in
            if let result = cameraViewModel.detectionResult {
                let imageRect = calculateImageRect(image: image, geometry: geometry)
                
                ForEach(result.cavities, id: \.id) { cavity in
                    cavityBoundingBoxView(cavity: cavity, imageRect: imageRect)
                }
            }
        }
    }
    
    private func calculateImageRect(image: UIImage, geometry: GeometryProxy) -> CGRect {
        let imageAspectRatio = image.size.width / image.size.height
        let viewAspectRatio = geometry.size.width / geometry.size.height
        
        if imageAspectRatio > viewAspectRatio {
            // Image is wider than view - fit to width
            let imageHeight = geometry.size.width / imageAspectRatio
            let yOffset = (geometry.size.height - imageHeight) / 2
            return CGRect(x: 0, y: yOffset, width: geometry.size.width, height: imageHeight)
        } else {
            // Image is taller than view - fit to height
            let imageWidth = geometry.size.height * imageAspectRatio
            let xOffset = (geometry.size.width - imageWidth) / 2
            return CGRect(x: xOffset, y: 0, width: imageWidth, height: geometry.size.height)
        }
    }
    
    private func cavityBoundingBoxView(cavity: CavityDetection, imageRect: CGRect) -> some View {
        Rectangle()
            .stroke(severityColor(cavity.severity), lineWidth: 3)
            .frame(
                width: cavity.boundingBox.width * imageRect.width,
                height: cavity.boundingBox.height * imageRect.height
            )
            .position(
                x: imageRect.minX + cavity.boundingBox.x * imageRect.width + cavity.boundingBox.width * imageRect.width / 2,
                y: imageRect.minY + cavity.boundingBox.y * imageRect.height + cavity.boundingBox.height * imageRect.height / 2
            )
            .overlay(
                Text("\(Int(cavity.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(severityColor(cavity.severity))
                    .cornerRadius(4)
                    .position(
                        x: imageRect.minX + cavity.boundingBox.x * imageRect.width + cavity.boundingBox.width * imageRect.width / 2,
                        y: imageRect.minY + cavity.boundingBox.y * imageRect.height - 10
                    )
            )
    }
    
    private func nextStepsView(result: DetectionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Steps:")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if result.cavities.isEmpty {
                Text("• Continue regular oral hygiene practices")
                Text("• Schedule routine dental checkups")
                Text("• Maintain healthy eating habits")
            } else {
                Text("• Schedule a dental appointment")
                Text("• Discuss treatment options with your dentist")
                Text("• Maintain good oral hygiene")
                if result.summary.urgencyLevel == .urgent || result.summary.urgencyLevel == .emergency {
                    Text("• Consider scheduling an urgent appointment")
                }
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
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
    
    private func urgencyColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .routine:
            return .green
        case .moderate:
            return .orange
        case .urgent:
            return .red
        case .emergency:
            return .purple
        }
    }
    
    private func urgencyIcon(_ urgency: UrgencyLevel) -> String {
        switch urgency {
        case .routine:
            return "checkmark.circle"
        case .moderate:
            return "exclamationmark.triangle"
        case .urgent:
            return "exclamationmark.circle"
        case .emergency:
            return "cross.circle"
        }
    }
}

// MARK: - Preview

struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let cameraViewModel = CameraViewModel()
        
        // Create mock detection result
        let mockBoundingBox = BoundingBox(x: 0.3, y: 0.4, width: 0.2, height: 0.15)
        let mockCavity = CavityDetection(
            boundingBox: mockBoundingBox,
            confidence: 0.85,
            severity: .moderate
        )
        
        let mockResult = DetectionResult(
            cavities: [mockCavity],
            overallConfidence: 0.85,
            imageInfo: ImageInfo(originalSize: CGSize(width: 1000, height: 1000)),
            summary: AnalysisSummary(
                totalCavities: 1,
                mostSevereCavity: .moderate,
                averageConfidence: 0.85,
                urgencyLevel: .moderate,
                observations: "One moderate cavity detected. Consult with a dentist for proper treatment."
            )
        )
        
        cameraViewModel.detectionResult = mockResult
        cameraViewModel.selectedImage = UIImage(systemName: "photo")
        
        return ResultsView(cameraViewModel: cameraViewModel)
    }
}
