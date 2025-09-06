//
//  CavityDetectionModels.swift
//  iDENTify
//
//  Created by AI Assistant on $(date)
//  Copyright © 2024 iDENTify. All rights reserved.
//

import Foundation
import CoreGraphics

// MARK: - Cavity Detection Models

/// Represents the severity level of a detected cavity
public enum CavitySeverity: String, CaseIterable, Codable {
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
    
    /// Display name for UI presentation
    public var displayName: String {
        switch self {
        case .mild:
            return "Mild Cavity"
        case .moderate:
            return "Moderate Cavity"
        case .severe:
            return "Severe Cavity"
        }
    }
    
    /// Color representation for UI visualization
    public var colorHex: String {
        switch self {
        case .mild:
            return "#FFD700" // Gold
        case .moderate:
            return "#FF8C00" // Dark Orange
        case .severe:
            return "#FF4500" // Red Orange
        }
    }
    
    /// Priority level for treatment recommendations
    public var priority: Int {
        switch self {
        case .mild:
            return 1
        case .moderate:
            return 2
        case .severe:
            return 3
        }
    }
}

/// Represents a bounding box with normalized coordinates
public struct BoundingBox: Codable, Equatable {
    /// X coordinate of the top-left corner (0.0 to 1.0)
    public let x: Double
    
    /// Y coordinate of the top-left corner (0.0 to 1.0)
    public let y: Double
    
    /// Width of the bounding box (0.0 to 1.0)
    public let width: Double
    
    /// Height of the bounding box (0.0 to 1.0)
    public let height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = max(0.0, min(1.0, x))
        self.y = max(0.0, min(1.0, y))
        self.width = max(0.0, min(1.0, width))
        self.height = max(0.0, min(1.0, height))
    }
    
    /// Convert normalized coordinates to absolute coordinates
    public func toAbsoluteCoordinates(imageWidth: Int, imageHeight: Int) -> CGRect {
        let absoluteX = x * Double(imageWidth)
        let absoluteY = y * Double(imageHeight)
        let absoluteWidth = width * Double(imageWidth)
        let absoluteHeight = height * Double(imageHeight)
        
        return CGRect(
            x: absoluteX,
            y: absoluteY,
            width: absoluteWidth,
            height: absoluteHeight
        )
    }
    
    /// Calculate the center point of the bounding box
    public var center: CGPoint {
        return CGPoint(
            x: x + width / 2.0,
            y: y + height / 2.0
        )
    }
    
    /// Calculate the area of the bounding box
    public var area: Double {
        return width * height
    }
}

/// Represents an individual cavity detection result
public struct CavityDetection: Codable, Identifiable, Equatable {
    /// Unique identifier for the detection
    public let id: UUID
    
    /// Bounding box coordinates (normalized)
    public let boundingBox: BoundingBox
    
    /// Confidence score (0.0 to 1.0)
    public let confidence: Double
    
    /// Severity level of the cavity
    public let severity: CavitySeverity
    
    /// Class ID for multi-class detection
    public let classId: Int
    
    /// Timestamp when the detection was made
    public let timestamp: Date
    
    /// Additional metadata about the detection
    public let metadata: DetectionMetadata
    
    public init(
        boundingBox: BoundingBox,
        confidence: Double,
        severity: CavitySeverity,
        classId: Int = 0,
        metadata: DetectionMetadata = DetectionMetadata()
    ) {
        self.id = UUID()
        self.boundingBox = boundingBox
        self.confidence = max(0.0, min(1.0, confidence))
        self.severity = severity
        self.classId = classId
        self.timestamp = Date()
        self.metadata = metadata
    }
    
    /// Check if this detection overlaps significantly with another detection
    public func overlaps(with other: CavityDetection, threshold: Double = 0.3) -> Bool {
        let intersection = boundingBox.intersection(with: other.boundingBox)
        let union = boundingBox.area + other.boundingBox.area - intersection.area
        
        if union <= 0 { return false }
        
        let overlapRatio = intersection.area / union
        return overlapRatio >= threshold
    }
}

/// Additional metadata for cavity detection
public struct DetectionMetadata: Codable, Equatable {
    /// Model version used for detection
    public let modelVersion: String
    
    /// Processing time in milliseconds
    public let processingTimeMs: Double
    
    /// Image preprocessing parameters used
    public let preprocessingParams: PreprocessingParams
    
    /// Additional notes or observations
    public let notes: String?
    
    public init(
        modelVersion: String = "aviScan-YOLOv11n-v1.0",
        processingTimeMs: Double = 0.0,
        preprocessingParams: PreprocessingParams = PreprocessingParams(),
        notes: String? = nil
    ) {
        self.modelVersion = modelVersion
        self.processingTimeMs = processingTimeMs
        self.preprocessingParams = preprocessingParams
        self.notes = notes
    }
}

/// Parameters used for image preprocessing
public struct PreprocessingParams: Codable, Equatable {
    /// Input image size used for the model
    public let inputSize: CGSize
    
    /// Normalization method applied
    public let normalizationMethod: String
    
    /// Color space conversion applied
    public let colorSpace: String
    
    /// Letterbox draw rectangle (normalized coordinates)
    public let drawRect: CGRect
    
    /// Offset X for letterboxing
    public let offsetX: Double
    
    /// Offset Y for letterboxing
    public let offsetY: Double
    
    /// Draw width for letterboxing
    public let drawWidth: Double
    
    /// Draw height for letterboxing
    public let drawHeight: Double
    
    public init(
        inputSize: CGSize = CGSize(width: 640, height: 640),
        normalizationMethod: String = "minmax",
        colorSpace: String = "RGB",
        drawRect: CGRect = CGRect(x: 0, y: 0, width: 640, height: 640),
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        drawWidth: Double = 640.0,
        drawHeight: Double = 640.0
    ) {
        self.inputSize = inputSize
        self.normalizationMethod = normalizationMethod
        self.colorSpace = colorSpace
        self.drawRect = drawRect
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.drawWidth = drawWidth
        self.drawHeight = drawHeight
    }
}

/// Overall result of cavity detection analysis
public struct DetectionResult: Codable, Identifiable {
    /// Unique identifier for the analysis session
    public let id: UUID
    
    /// Array of detected cavities
    public let cavities: [CavityDetection]
    
    /// Overall confidence score for the analysis
    public let overallConfidence: Double
    
    /// Analysis timestamp
    public let timestamp: Date
    
    /// Image information
    public let imageInfo: ImageInfo
    
    /// Analysis summary
    public let summary: AnalysisSummary
    
    public init(
        cavities: [CavityDetection],
        overallConfidence: Double,
        imageInfo: ImageInfo,
        summary: AnalysisSummary
    ) {
        self.id = UUID()
        self.cavities = cavities
        self.overallConfidence = max(0.0, min(1.0, overallConfidence))
        self.timestamp = Date()
        self.imageInfo = imageInfo
        self.summary = summary
    }
    
    /// Check if any cavities were detected
    public var hasCavities: Bool {
        return !cavities.isEmpty
    }
    
    /// Get cavities sorted by severity (most severe first)
    public var cavitiesBySeverity: [CavityDetection] {
        return cavities.sorted { $0.severity.priority > $1.severity.priority }
    }
    
    /// Get cavities sorted by confidence (highest first)
    public var cavitiesByConfidence: [CavityDetection] {
        return cavities.sorted { $0.confidence > $1.confidence }
    }
    
    /// Count cavities by severity level
    public var severityCounts: [CavitySeverity: Int] {
        var counts: [CavitySeverity: Int] = [:]
        for cavity in cavities {
            counts[cavity.severity, default: 0] += 1
        }
        return counts
    }
}

/// Information about the analyzed image
public struct ImageInfo: Codable, Equatable {
    /// Original image dimensions
    public let originalSize: CGSize
    
    /// Image format/type
    public let format: String
    
    /// Image quality metrics
    public let qualityMetrics: ImageQualityMetrics
    
    /// Processing parameters applied
    public let processingParams: PreprocessingParams
    
    public init(
        originalSize: CGSize,
        format: String = "Unknown",
        qualityMetrics: ImageQualityMetrics = ImageQualityMetrics(),
        processingParams: PreprocessingParams = PreprocessingParams()
    ) {
        self.originalSize = originalSize
        self.format = format
        self.qualityMetrics = qualityMetrics
        self.processingParams = processingParams
    }
}

/// Image quality metrics
public struct ImageQualityMetrics: Codable, Equatable {
    /// Blur score (0.0 = very blurry, 1.0 = very sharp)
    public let blurScore: Double
    
    /// Brightness score (0.0 = very dark, 1.0 = very bright)
    public let brightnessScore: Double
    
    /// Contrast score (0.0 = low contrast, 1.0 = high contrast)
    public let contrastScore: Double
    
    /// Overall quality score
    public let overallQuality: Double
    
    public init(
        blurScore: Double = 0.0,
        brightnessScore: Double = 0.0,
        contrastScore: Double = 0.0,
        overallQuality: Double = 0.0
    ) {
        self.blurScore = max(0.0, min(1.0, blurScore))
        self.brightnessScore = max(0.0, min(1.0, brightnessScore))
        self.contrastScore = max(0.0, min(1.0, contrastScore))
        self.overallQuality = max(0.0, min(1.0, overallQuality))
    }
}

/// Summary of the analysis results
public struct AnalysisSummary: Codable, Equatable {
    /// Total number of cavities detected
    public let totalCavities: Int
    
    /// Most severe cavity found
    public let mostSevereCavity: CavitySeverity?
    
    /// Average confidence score
    public let averageConfidence: Double
    
    /// Recommendation for treatment urgency
    public let urgencyLevel: UrgencyLevel
    
    /// General observations
    public let observations: String?
    
    public init(
        totalCavities: Int,
        mostSevereCavity: CavitySeverity? = nil,
        averageConfidence: Double = 0.0,
        urgencyLevel: UrgencyLevel = .routine,
        observations: String? = nil
    ) {
        self.totalCavities = max(0, totalCavities)
        self.mostSevereCavity = mostSevereCavity
        self.averageConfidence = max(0.0, min(1.0, averageConfidence))
        self.urgencyLevel = urgencyLevel
        self.observations = observations
    }
}

/// Urgency level for treatment recommendations
public enum UrgencyLevel: String, CaseIterable, Codable {
    case routine = "routine"
    case moderate = "moderate"
    case urgent = "urgent"
    case emergency = "emergency"
    
    /// Display name for UI presentation
    public var displayName: String {
        switch self {
        case .routine:
            return "Routine Check"
        case .moderate:
            return "Moderate Priority"
        case .urgent:
            return "Urgent Care"
        case .emergency:
            return "Emergency Care"
        }
    }
    
    /// Priority level (1 = lowest, 4 = highest)
    public var priority: Int {
        switch self {
        case .routine:
            return 1
        case .moderate:
            return 2
        case .urgent:
            return 3
        case .emergency:
            return 4
        }
    }
}

/// Errors that can occur during cavity detection
public enum DetectionError: Error, LocalizedError {
    case modelNotFound
    case modelLoadingFailed(String)
    case imageProcessingFailed(String)
    case inferenceFailed(String)
    case invalidInput(String)
    case insufficientConfidence
    case processingTimeout
    case memoryError
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Cavity detection model not found. Please ensure the model file is included in the app bundle."
        case .modelLoadingFailed(let reason):
            return "Failed to load cavity detection model: \(reason)"
        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .inferenceFailed(let reason):
            return "Model inference failed: \(reason)"
        case .invalidInput(let reason):
            return "Invalid input provided: \(reason)"
        case .insufficientConfidence:
            return "Detection confidence is too low to provide reliable results."
        case .processingTimeout:
            return "Processing timeout. The image may be too large or complex."
        case .memoryError:
            return "Insufficient memory to process the image."
        case .unknownError(let reason):
            return "An unknown error occurred: \(reason)"
        }
    }
}

// MARK: - Extensions

extension BoundingBox {
    /// Calculate intersection with another bounding box
    public func intersection(with other: BoundingBox) -> BoundingBox {
        let x1 = max(self.x, other.x)
        let y1 = max(self.y, other.y)
        let x2 = min(self.x + self.width, other.x + other.width)
        let y2 = min(self.y + self.height, other.y + other.height)
        
        if x2 <= x1 || y2 <= y1 {
            return BoundingBox(x: 0, y: 0, width: 0, height: 0)
        }
        
        return BoundingBox(
            x: x1,
            y: y1,
            width: x2 - x1,
            height: y2 - y1
        )
    }
}

extension DetectionResult {
    /// Generate a human-readable summary
    public var summaryText: String {
        if cavities.isEmpty {
            return "No cavities detected. Your teeth appear healthy!"
        }
        
        let severityCounts = self.severityCounts
        var summary = "Detected \(cavities.count) cavity(ies): "
        
        let severityDescriptions = severityCounts.compactMap { severity, count in
            count > 0 ? "\(count) \(severity.displayName.lowercased())" : nil
        }
        
        summary += severityDescriptions.joined(separator: ", ")
        
        if let mostSevere = self.summary.mostSevereCavity {
            summary += ". Most severe: \(mostSevere.displayName)"
        }
        
        return summary
    }
}
