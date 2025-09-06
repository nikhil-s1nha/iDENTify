//
//  ImageProcessingUtils.swift
//  iDENTify
//
//  Created by AI Assistant on $(date)
//  Copyright © 2024 iDENTify. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics
import CoreVideo
import Accelerate

/// Utility class for image preprocessing and post-processing operations
/// required for cavity detection using TensorFlow Lite models.
public class ImageProcessingUtils {
    
    // MARK: - Constants
    
    /// Standard input size for YOLOv11n model
    public static let modelInputSize = CGSize(width: 640, height: 640)
    
    /// Number of color channels (RGB)
    public static let colorChannels = 3
    
    /// Expected pixel value range for model input
    public static let pixelValueRange = 0.0...1.0
    
    // MARK: - Image Preprocessing
    
    /// Resize and normalize an image for YOLOv11n model input
    /// - Parameters:
    ///   - image: Input UIImage
    ///   - targetSize: Target size for resizing (default: modelInputSize)
    ///   - maintainAspectRatio: Whether to maintain aspect ratio during resize (default: true for YOLO)
    /// - Returns: Tuple containing preprocessed CVPixelBuffer and preprocessing parameters
    /// - Throws: DetectionError if preprocessing fails
    public static func preprocessImage(
        _ image: UIImage,
        targetSize: CGSize = modelInputSize,
        maintainAspectRatio: Bool = true
    ) throws -> (CVPixelBuffer, PreprocessingParams) {
        
        // Validate input image
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidInput("Unable to get CGImage from UIImage")
        }
        
        // Resize image and get letterbox parameters
        let (resizedImage, preprocessingParams) = try resizeImage(
            cgImage,
            targetSize: targetSize,
            maintainAspectRatio: maintainAspectRatio
        )
        
        // Convert to CVPixelBuffer
        let pixelBuffer = try createPixelBuffer(from: resizedImage, size: targetSize)
        
        return (pixelBuffer, preprocessingParams)
    }
    
    /// Resize a CGImage to target size
    /// - Parameters:
    ///   - cgImage: Source CGImage
    ///   - targetSize: Target size for resizing
    ///   - maintainAspectRatio: Whether to maintain aspect ratio
    /// - Returns: Tuple containing resized CGImage and preprocessing parameters
    /// - Throws: DetectionError if resize fails
    private static func resizeImage(
        _ cgImage: CGImage,
        targetSize: CGSize,
        maintainAspectRatio: Bool
    ) throws -> (CGImage, PreprocessingParams) {
        
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw DetectionError.imageProcessingFailed("Failed to create CGContext for resizing")
        }
        
        var preprocessingParams: PreprocessingParams
        
        if maintainAspectRatio {
            // Calculate aspect ratio preserving dimensions with letterbox padding
            let imageAspectRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
            let targetAspectRatio = targetSize.width / targetSize.height
            
            var drawSize = targetSize
            if imageAspectRatio > targetAspectRatio {
                // Image is wider than target - fit to width, pad height
                drawSize.height = targetSize.width / imageAspectRatio
            } else {
                // Image is taller than target - fit to height, pad width
                drawSize.width = targetSize.height * imageAspectRatio
            }
            
            let xOffset = (targetSize.width - drawSize.width) / 2
            let yOffset = (targetSize.height - drawSize.height) / 2
            
            // Clear background to black (letterbox padding)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Draw image centered
            context.draw(cgImage, in: CGRect(x: xOffset, y: yOffset, width: drawSize.width, height: drawSize.height))
            
            // Create preprocessing parameters with letterbox info
            preprocessingParams = PreprocessingParams(
                inputSize: targetSize,
                drawRect: CGRect(x: xOffset, y: yOffset, width: drawSize.width, height: drawSize.height),
                offsetX: xOffset,
                offsetY: yOffset,
                drawWidth: drawSize.width,
                drawHeight: drawSize.height
            )
        } else {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // No letterboxing, full target size
            preprocessingParams = PreprocessingParams(
                inputSize: targetSize,
                drawRect: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height),
                offsetX: 0.0,
                offsetY: 0.0,
                drawWidth: targetSize.width,
                drawHeight: targetSize.height
            )
        }
        
        guard let resizedImage = context.makeImage() else {
            throw DetectionError.imageProcessingFailed("Failed to create resized CGImage")
        }
        
        return (resizedImage, preprocessingParams)
    }
    
    /// Create CVPixelBuffer from CGImage
    /// - Parameters:
    ///   - cgImage: Source CGImage
    ///   - size: Target size for the pixel buffer
    /// - Returns: CVPixelBuffer containing the image data
    /// - Throws: DetectionError if conversion fails
    private static func createPixelBuffer(from cgImage: CGImage, size: CGSize) throws -> CVPixelBuffer {
        let width = Int(size.width)
        let height = Int(size.height)
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw DetectionError.imageProcessingFailed("Failed to create CVPixelBuffer")
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw DetectionError.imageProcessingFailed("Failed to create CGContext for pixel buffer")
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    
    // MARK: - CVPixelBuffer to Float32 Array Conversion
    
    /// Convert CVPixelBuffer to Float32 array for TensorFlow Lite input
    /// - Parameter pixelBuffer: CVPixelBuffer containing image data
    /// - Returns: Float32 array in [batch, height, width, channels] format
    /// - Throws: DetectionError if conversion fails
    public static func pixelBufferToFloat32Array(_ pixelBuffer: CVPixelBuffer) throws -> [Float32] {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw DetectionError.imageProcessingFailed("Failed to get pixel buffer base address")
        }
        
        let pixelData = baseAddress.assumingMemoryBound(to: UInt8.self)
        var floatArray: [Float32] = []
        floatArray.reserveCapacity(width * height * colorChannels)
        
        // Convert BGRA to RGB and normalize to [0, 1]
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4
                
                // Extract RGB values and normalize
                let r = Float32(pixelData[pixelIndex + 2]) / 255.0
                let g = Float32(pixelData[pixelIndex + 1]) / 255.0
                let b = Float32(pixelData[pixelIndex]) / 255.0
                
                floatArray.append(r)
                floatArray.append(g)
                floatArray.append(b)
            }
        }
        
        return floatArray
    }
    
    // MARK: - UIImage to CVPixelBuffer Conversion
    
    /// Convert UIImage to CVPixelBuffer
    /// - Parameter image: UIImage to convert
    /// - Returns: CVPixelBuffer containing the image data
    /// - Throws: DetectionError if conversion fails
    public static func uiImageToPixelBuffer(_ image: UIImage) throws -> CVPixelBuffer {
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidInput("Unable to get CGImage from UIImage")
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw DetectionError.imageProcessingFailed("Failed to create CVPixelBuffer from UIImage")
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw DetectionError.imageProcessingFailed("Failed to create CGContext for UIImage conversion")
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    // MARK: - Coordinate Transformation
    
    /// Convert model output coordinates to original image coordinates
    /// - Parameters:
    ///   - normalizedBox: Bounding box in normalized coordinates (0-1)
    ///   - originalSize: Original image size
    ///   - modelSize: Model input size used for inference
    ///   - preprocessingParams: Preprocessing parameters including letterbox info
    /// - Returns: Bounding box in original image coordinates
    public static func convertToOriginalCoordinates(
        normalizedBox: BoundingBox,
        originalSize: CGSize,
        modelSize: CGSize = modelInputSize,
        preprocessingParams: PreprocessingParams
    ) -> BoundingBox {
        
        // Step 1: Map model-space coords into the letterboxed draw rect
        let drawRectX = preprocessingParams.offsetX / modelSize.width
        let drawRectY = preprocessingParams.offsetY / modelSize.height
        let drawRectWidth = preprocessingParams.drawWidth / modelSize.width
        let drawRectHeight = preprocessingParams.drawHeight / modelSize.height
        
        // Adjust coordinates to account for letterboxing
        let adjustedX = (normalizedBox.x - drawRectX) / drawRectWidth
        let adjustedY = (normalizedBox.y - drawRectY) / drawRectHeight
        let adjustedWidth = normalizedBox.width / drawRectWidth
        let adjustedHeight = normalizedBox.height / drawRectHeight
        
        // Step 2: Scale to original image dimensions
        let x = adjustedX * originalSize.width
        let y = adjustedY * originalSize.height
        let width = adjustedWidth * originalSize.width
        let height = adjustedHeight * originalSize.height
        
        // Step 3: Normalize to original image dimensions
        let normalizedX = x / originalSize.width
        let normalizedY = y / originalSize.height
        let normalizedWidth = width / originalSize.width
        let normalizedHeight = height / originalSize.height
        
        return BoundingBox(
            x: normalizedX,
            y: normalizedY,
            width: normalizedWidth,
            height: normalizedHeight
        )
    }
    
    // MARK: - Non-Maximum Suppression (NMS)
    
    /// Apply Non-Maximum Suppression to filter overlapping detections
    /// - Parameters:
    ///   - detections: Array of cavity detections
    ///   - iouThreshold: Intersection over Union threshold (default: 0.4)
    ///   - confidenceThreshold: Minimum confidence threshold (default: 0.5)
    /// - Returns: Filtered array of detections
    public static func applyNonMaximumSuppression(
        detections: [CavityDetection],
        iouThreshold: Double = 0.4,
        confidenceThreshold: Double = 0.5
    ) -> [CavityDetection] {
        
        // Filter by confidence threshold
        let filteredDetections = detections.filter { $0.confidence >= confidenceThreshold }
        
        // Group detections by class ID for per-class NMS
        let detectionsByClass = Dictionary(grouping: filteredDetections) { $0.classId }
        
        var selectedDetections: [CavityDetection] = []
        
        // Apply NMS per class
        for (classId, classDetections) in detectionsByClass {
            let classNMSResult = applyNMSForClass(
                detections: classDetections,
                iouThreshold: iouThreshold
            )
            selectedDetections.append(contentsOf: classNMSResult)
        }
        
        return selectedDetections
    }
    
    /// Apply NMS for a specific class
    /// - Parameters:
    ///   - detections: Detections for a single class
    ///   - iouThreshold: IoU threshold for suppression
    /// - Returns: Filtered detections for the class
    private static func applyNMSForClass(
        detections: [CavityDetection],
        iouThreshold: Double
    ) -> [CavityDetection] {
        
        // Sort by confidence (highest first)
        let sortedDetections = detections.sorted { $0.confidence > $1.confidence }
        
        var selectedDetections: [CavityDetection] = []
        var suppressedIndices: Set<Int> = []
        
        for (index, detection) in sortedDetections.enumerated() {
            if suppressedIndices.contains(index) {
                continue
            }
            
            selectedDetections.append(detection)
            
            // Suppress overlapping detections within the same class
            for (otherIndex, otherDetection) in sortedDetections.enumerated() {
                if otherIndex <= index || suppressedIndices.contains(otherIndex) {
                    continue
                }
                
                let iou = calculateIoU(detection.boundingBox, otherDetection.boundingBox)
                if iou > iouThreshold {
                    suppressedIndices.insert(otherIndex)
                }
            }
        }
        
        return selectedDetections
    }
    
    /// Calculate Intersection over Union (IoU) between two bounding boxes
    /// - Parameters:
    ///   - box1: First bounding box
    ///   - box2: Second bounding box
    /// - Returns: IoU value between 0 and 1
    private static func calculateIoU(_ box1: BoundingBox, _ box2: BoundingBox) -> Double {
        let intersection = box1.intersection(with: box2)
        let intersectionArea = intersection.area
        
        if intersectionArea <= 0 {
            return 0.0
        }
        
        let unionArea = box1.area + box2.area - intersectionArea
        return intersectionArea / unionArea
    }
    
    // MARK: - Image Quality Validation
    
    /// Validate image quality for dental photo analysis
    /// - Parameter image: UIImage to validate
    /// - Returns: ImageQualityMetrics with quality scores
    public static func validateImageQuality(_ image: UIImage) -> ImageQualityMetrics {
        guard let cgImage = image.cgImage else {
            return ImageQualityMetrics()
        }
        
        let blurScore = calculateBlurScore(cgImage)
        let brightnessScore = calculateBrightnessScore(cgImage)
        let contrastScore = calculateContrastScore(cgImage)
        
        // Calculate overall quality score
        let overallQuality = (blurScore + brightnessScore + contrastScore) / 3.0
        
        return ImageQualityMetrics(
            blurScore: blurScore,
            brightnessScore: brightnessScore,
            contrastScore: contrastScore,
            overallQuality: overallQuality
        )
    }
    
    /// Calculate blur score using Laplacian variance
    /// - Parameter cgImage: CGImage to analyze
    /// - Returns: Blur score between 0 and 1
    private static func calculateBlurScore(_ cgImage: CGImage) -> Double {
        // Simplified blur detection using image dimensions and basic analysis
        let width = cgImage.width
        let height = cgImage.height
        
        // Basic heuristic: larger images tend to be sharper
        let sizeScore = min(1.0, Double(width * height) / (1000 * 1000))
        
        // Additional blur detection could be implemented using edge detection
        return sizeScore
    }
    
    /// Calculate brightness score
    /// - Parameter cgImage: CGImage to analyze
    /// - Returns: Brightness score between 0 and 1
    private static func calculateBrightnessScore(_ cgImage: CGImage) -> Double {
        // Simplified brightness calculation
        // In a real implementation, you would analyze pixel values
        return 0.8 // Placeholder value
    }
    
    /// Calculate contrast score
    /// - Parameter cgImage: CGImage to analyze
    /// - Returns: Contrast score between 0 and 1
    private static func calculateContrastScore(_ cgImage: CGImage) -> Double {
        // Simplified contrast calculation
        // In a real implementation, you would calculate standard deviation of pixel values
        return 0.7 // Placeholder value
    }
    
    // MARK: - Color Space Conversion
    
    /// Convert image to RGB color space
    /// - Parameter image: UIImage to convert
    /// - Returns: UIImage in RGB color space
    /// - Throws: DetectionError if conversion fails
    public static func convertToRGB(_ image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidInput("Unable to get CGImage from UIImage")
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw DetectionError.imageProcessingFailed("Failed to create CGContext for RGB conversion")
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let rgbImage = context.makeImage() else {
            throw DetectionError.imageProcessingFailed("Failed to create RGB CGImage")
        }
        
        return UIImage(cgImage: rgbImage)
    }
    
    // MARK: - Utility Functions
    
    /// Check if image dimensions are suitable for cavity detection
    /// - Parameter image: UIImage to check
    /// - Returns: True if image dimensions are adequate
    public static func isImageSizeAdequate(_ image: UIImage) -> Bool {
        let size = image.size
        let minDimension = min(size.width, size.height)
        return minDimension >= 300 // Minimum 300 pixels for reliable detection
    }
    
    /// Get recommended image size for optimal detection
    /// - Returns: Recommended CGSize for dental photos
    public static func getRecommendedImageSize() -> CGSize {
        return CGSize(width: 1024, height: 1024) // Square aspect ratio recommended
    }
}
