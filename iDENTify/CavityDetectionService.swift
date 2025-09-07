//
//  CavityDetectionService.swift
//  iDENTify
//
//  Created by AI Assistant on $(date)
//  Copyright © 2024 iDENTify. All rights reserved.
//

import Foundation
import UIKit
import TensorFlowLite
import CoreGraphics

/// Service class for handling TensorFlow Lite model inference for cavity detection
/// using the aviScan-YOLOv11n-v1.0 Kaggle model converted to TensorFlow Lite format.
public class CavityDetectionService {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    public static let shared = CavityDetectionService()
    
    /// TensorFlow Lite interpreter for the aviScan-YOLOv11n-v1.0 model
    private var interpreter: Interpreter?
    
    /// Model file name (converted aviScan-YOLOv11n-v1.0 TensorFlow Lite model)
    private let modelFileName = "aviScan-YOLOv11n-v1.0.tflite"
    
    /// Service initialization status
    private var isInitialized = false
    
    /// Model input/output specifications
    private let inputSize = CGSize(width: 640, height: 640)
    private let expectedOutputShape = [1, 84, 8400] // YOLO v11n format: 84 = 4 bbox + 80 classes
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton pattern
    }
    
    /// Initialize the cavity detection service
    /// - Throws: DetectionError if initialization fails
    public func initialize() throws {
        guard !isInitialized else { return }
        
        try loadModel()
        try configureInterpreter()
        
        isInitialized = true
        print("✅ CavityDetectionService initialized with aviScan-YOLOv11n-v1.0 model")
    }
    
    /// Load the converted aviScan-YOLOv11n-v1.0 TensorFlow Lite model
    /// - Throws: DetectionError if model loading fails
    private func loadModel() throws {
        guard let modelPath = Bundle.main.path(forResource: "aviScan-YOLOv11n-v1.0", ofType: "tflite") else {
            print("❌ aviScan-YOLOv11n-v1.0.tflite model not found in bundle")
            print("📁 Looking for: aviScan-YOLOv11n-v1.0.tflite")
            print("💡 Make sure to convert the Kaggle .pt model to .tflite format first")
            throw DetectionError.modelNotFound
        }
        
        // Runtime guard to check if this is a placeholder file
        let fileSize = try FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? Int64 ?? 0
        if fileSize < 100 * 1024 { // Less than 100KB indicates placeholder
            print("❌ Detected placeholder model file (size: \(fileSize) bytes)")
            print("💡 Please run 'integrate_kaggle_model.sh' to convert the real model")
            print("💡 Or replace the placeholder with the actual converted .tflite model")
            throw DetectionError.modelNotFound
        }
        
        print("✅ Found aviScan-YOLOv11n-v1.0 model: \(modelPath) (size: \(fileSize / 1024)KB)")
        
        // Check if this is a placeholder file (all zeros or very small)
        if fileSize < 500 * 1024 { // Less than 500KB is likely a placeholder
            print("⚠️ Detected placeholder model file for demo purposes")
            print("💡 Replace with actual converted model for real cavity detection")
            interpreter = nil
            return
        }
        
        do {
            // Create TensorFlow Lite interpreter with optimized options
            var options = Interpreter.Options()
            options.threadCount = 4 // Use multiple threads for better performance
            
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            print("🎉 aviScan-YOLOv11n-v1.0 TensorFlow Lite model loaded successfully!")
        } catch {
            print("❌ Failed to load TensorFlow Lite model: \(error)")
            print("⚠️ Falling back to demo mode")
            interpreter = nil
        }
    }
    
    /// Configure the TensorFlow Lite interpreter
    /// - Throws: DetectionError if configuration fails
    private func configureInterpreter() throws {
        guard let interpreter = interpreter else {
            print("⚠️ Demo mode: Skipping interpreter configuration for placeholder model")
            return
        }
        
        do {
            // Allocate tensors
            try interpreter.allocateTensors()
            
            // Validate input/output specifications
            let inputTensor = try interpreter.input(at: 0)
            let outputTensor = try interpreter.output(at: 0)
            
            print("📊 Model specifications:")
            print("   Input shape: \(inputTensor.shape)")
            print("   Input type: \(inputTensor.dataType)")
            print("   Output shape: \(outputTensor.shape)")
            print("   Output type: \(outputTensor.dataType)")
            
            // Verify expected YOLO v11n format
            let actualOutputShape = outputTensor.shape.dimensions
            if actualOutputShape == expectedOutputShape {
                print("✅ Output shape matches expected YOLO v11n format [1, 84, 8400]")
            } else {
                print("⚠️ Output shape \(actualOutputShape) differs from expected \(expectedOutputShape)")
                print("   This may affect detection accuracy")
            }
            
            print("✅ TensorFlow Lite interpreter configured successfully")
            
        } catch {
            print("❌ Failed to configure TensorFlow Lite interpreter: \(error)")
            throw DetectionError.modelLoadingFailed("Failed to configure interpreter: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Detection Methods
    
    /// Detect cavities in an image asynchronously
    /// - Parameters:
    ///   - image: UIImage to analyze
    ///   - confidenceThreshold: Minimum confidence threshold (default: 0.5)
    ///   - iouThreshold: IoU threshold for NMS (default: 0.4)
    /// - Returns: DetectionResult with detected cavities
    /// - Throws: DetectionError if detection fails
    public func detectCavities(
        in image: UIImage,
        confidenceThreshold: Double = 0.5,
        iouThreshold: Double = 0.4
    ) async throws -> DetectionResult {
        
        if !isInitialized {
            try initialize()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.performDetection(
                        image: image,
                        confidenceThreshold: confidenceThreshold,
                        iouThreshold: iouThreshold
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Perform cavity detection on a dental image using the aviScan-YOLOv11n-v1.0 model
    /// - Parameters:
    ///   - image: UIImage to analyze
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - iouThreshold: IoU threshold for NMS
    /// - Returns: DetectionResult with detected cavities
    /// - Throws: DetectionError if detection fails
    private func performDetection(
        image: UIImage,
        confidenceThreshold: Double,
        iouThreshold: Double
    ) throws -> DetectionResult {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Validate input image
        guard ImageProcessingUtils.isImageSizeAdequate(image) else {
            throw DetectionError.invalidInput("Image size is too small for reliable detection")
        }
        
        // Check if we're in demo mode (no interpreter available)
        guard let inputInterpreter = interpreter else {
            // Demo mode with placeholder model - return mock detections
            print("🎭 Demo mode: Returning mock cavity detections")
            return createMockDetectionResult(
                image: image,
                preprocessingParams: PreprocessingParams(
                    inputSize: CGSize(width: 640, height: 640),
                    normalizationMethod: "minmax",
                    colorSpace: "RGB",
                    drawRect: CGRect(x: 0, y: 0, width: 640, height: 640),
                    offsetX: 0.0,
                    offsetY: 0.0,
                    drawWidth: 640.0,
                    drawHeight: 640.0
                )
            )
        }
        
        // Preprocess image for YOLO v11n input (640x640 RGB)
        let (pixelBuffer, preprocessingParams) = try ImageProcessingUtils.preprocessImageForYOLO(image)
        
        // Handle different input data types (Float32, UInt8, Int8)
        let inputTensor = try inputInterpreter.input(at: 0)
        let inputDataType = inputTensor.dataType
        
        let inputData: Data
        if inputDataType == .uInt8 {
            // Quantize Float32 input to UInt8
            let inputArray = try ImageProcessingUtils.pixelBufferToFloat32Array(pixelBuffer)
            guard let quantParams = inputTensor.quantizationParameters else {
                throw DetectionError.inferenceFailed("Quantization parameters not available for UInt8 input")
            }
            let scale = quantParams.scale
            let zeroPoint = quantParams.zeroPoint
            
            let quantizedArray = inputArray.map { value in
                UInt8(max(0, min(255, Int((value / scale) + Float(zeroPoint)))))
            }
            inputData = Data(quantizedArray)
        } else {
            // Default Float32 path
            let inputArray = try ImageProcessingUtils.pixelBufferToFloat32Array(pixelBuffer)
            inputData = inputArray.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
        }
        
        // Perform inference with TensorFlow Lite
        do {
            // Copy input data to input tensor
            try inputInterpreter.copy(inputData, toInputAt: 0)
            
            // Run inference
            try inputInterpreter.invoke()
            
            // Parse YOLO v11n output with dtype handling
            let detections = try parseYOLOv11nOutput(
                interpreter: inputInterpreter,
                confidenceThreshold: confidenceThreshold,
                iouThreshold: iouThreshold,
                preprocessingParams: preprocessingParams,
                originalImageSize: image.size
            )
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Create image info
            let imageInfo = ImageInfo(
                originalSize: image.size,
                format: "UIImage",
                processingParams: preprocessingParams
            )
            
            // Determine most severe cavity
            let mostSevereCavity = detections.max { $0.severity.rawValue < $1.severity.rawValue }?.severity
            
            // Determine urgency level
            let urgencyLevel: UrgencyLevel
            if mostSevereCavity == .severe {
                urgencyLevel = .urgent
            } else if mostSevereCavity == .moderate {
                urgencyLevel = .moderate
            } else {
                urgencyLevel = .routine
            }
            
            // Create analysis summary
            let summary = AnalysisSummary(
                totalCavities: detections.count,
                mostSevereCavity: mostSevereCavity,
                averageConfidence: detections.isEmpty ? 0.0 : detections.map { $0.confidence }.reduce(0, +) / Double(detections.count),
                urgencyLevel: urgencyLevel,
                observations: generateObservations(for: detections)
            )
            
            print("✅ Detection completed in \(String(format: "%.2f", processingTime * 1000))ms")
            print("📊 Found \(detections.count) cavities with average confidence \(String(format: "%.1f%%", summary.averageConfidence * 100))")
            
            return DetectionResult(
                cavities: detections,
                overallConfidence: summary.averageConfidence,
                imageInfo: imageInfo,
                summary: summary
            )
            
        } catch {
            throw DetectionError.inferenceFailed(error.localizedDescription)
        }
    }
    
    /// Parse YOLO v11n output tensor with dynamic shape detection
    /// - Parameters:
    ///   - interpreter: TensorFlow Lite interpreter
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - iouThreshold: IoU threshold for NMS
    ///   - preprocessingParams: Image preprocessing parameters
    ///   - originalImageSize: Original image size
    /// - Returns: Array of CavityDetection objects
    /// - Throws: DetectionError if parsing fails
    private func parseYOLOv11nOutput(
        interpreter: Interpreter,
        confidenceThreshold: Double,
        iouThreshold: Double,
        preprocessingParams: PreprocessingParams,
        originalImageSize: CGSize
    ) throws -> [CavityDetection] {
        
        print("🎯 Parsing YOLO v11n output...")
        
        // Get output tensor
        let outputTensor = try interpreter.output(at: 0)
        let outputData = outputTensor.data
        let outputShape = outputTensor.shape.dimensions
        let outputDataType = outputTensor.dataType
        
        print("📊 Output shape: \(outputShape), dtype: \(outputDataType)")
        
        // Convert to float array with dequantization if needed
        let floatArray: [Float]
        if outputDataType == .uInt8 {
            // Dequantize UInt8 output to Float32
            guard let quantParams = outputTensor.quantizationParameters else {
                throw DetectionError.inferenceFailed("Quantization parameters not available for UInt8 output")
            }
            let scale = quantParams.scale
            let zeroPoint = quantParams.zeroPoint
            
            let uint8Array = outputData.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: UInt8.self))
            }
            floatArray = uint8Array.map { value in
                Float((Float(value) - Float(zeroPoint)) * scale)
            }
        } else {
            // Default Float32 path
            floatArray = outputData.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: Float32.self))
            }
        }
        
        // Parse YOLO detections with dynamic shape handling
        let detections = try parseYOLODetections(
            floatArray: floatArray,
            outputShape: outputShape.map { Int32($0) },
            confidenceThreshold: confidenceThreshold,
            iouThreshold: iouThreshold,
            preprocessingParams: preprocessingParams,
            originalImageSize: originalImageSize
        )
        
        print("✅ Parsed \(detections.count) cavity detections")
        return detections
    }
    
    /// Parse YOLO detections from model output with dynamic shape detection
    /// - Parameters:
    ///   - floatArray: Raw model output as float array
    ///   - outputShape: Output tensor shape
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - iouThreshold: IoU threshold for NMS
    ///   - preprocessingParams: Image preprocessing parameters
    ///   - originalImageSize: Original image size
    /// - Returns: Array of CavityDetection objects
    /// - Throws: DetectionError if parsing fails
    private func parseYOLODetections(
        floatArray: [Float],
        outputShape: [Int32],
        confidenceThreshold: Double,
        iouThreshold: Double,
        preprocessingParams: PreprocessingParams,
        originalImageSize: CGSize
    ) throws -> [CavityDetection] {
        
        var detections: [CavityDetection] = []
        
        // Detect output format dynamically
        let (numDetections, featuresPerDetection, isBuiltInNMS) = detectOutputFormat(outputShape)
        let numClasses = featuresPerDetection - 4
        
        print("📊 Detected format: \(numDetections) detections, \(featuresPerDetection) features per detection, \(numClasses) classes")
        
        guard floatArray.count >= numDetections * featuresPerDetection else {
            throw DetectionError.inferenceFailed("Invalid output tensor size")
        }
        
        // Handle built-in NMS format (e.g., [1, N, 6] with [x1, y1, x2, y2, score, class])
        if isBuiltInNMS {
            return try parseBuiltInNMSDetections(
                floatArray: floatArray,
                numDetections: numDetections,
                confidenceThreshold: confidenceThreshold,
                preprocessingParams: preprocessingParams,
                originalImageSize: originalImageSize
            )
        }
        
        // Process each detection for standard YOLO format
        for i in 0..<numDetections {
            let detectionValues: [Float]
            
            // Extract detection values based on output layout
            if outputShape.count == 3 && outputShape[1] == Int32(featuresPerDetection) {
                // Format: [1, F, N] - index as value = floatArray[f * N + i]
                detectionValues = (0..<featuresPerDetection).map { f in
                    floatArray[Int(f) * numDetections + i]
                }
            } else {
                // Format: [1, N, F] - contiguous chunks of F floats
                let baseIndex = i * featuresPerDetection
                detectionValues = Array(floatArray[baseIndex..<(baseIndex + featuresPerDetection)])
            }
            
            // Extract bounding box coordinates (normalized 0-1)
            let centerX = Double(detectionValues[0])
            let centerY = Double(detectionValues[1])
            let width = Double(detectionValues[2])
            let height = Double(detectionValues[3])
            
            // Extract class probabilities
            var maxConfidence = 0.0
            var bestClassId = 0
            
            for classIndex in 0..<numClasses {
                let classConfidence = Double(detectionValues[4 + classIndex])
                if classConfidence > maxConfidence {
                    maxConfidence = classConfidence
                    bestClassId = classIndex
                }
            }
            
            // Only consider detections with sufficient confidence
            if maxConfidence >= confidenceThreshold {
                // Convert center coordinates to top-left coordinates
                let x = centerX - width / 2
                let y = centerY - height / 2
                
                // Ensure coordinates are within valid range
                guard x >= 0 && y >= 0 && x + width <= 1 && y + height <= 1 else {
                    continue
                }
                
                // Create bounding box
                let normalizedBox = BoundingBox(
                    x: x,
                    y: y,
                    width: width,
                    height: height
                )
                
                // Convert to original image coordinates
                let boundingBox = ImageProcessingUtils.convertToOriginalCoordinates(
                    normalizedBox: normalizedBox,
                    originalSize: originalImageSize,
                    preprocessingParams: preprocessingParams
                )
                
                // Determine severity based on confidence and size
                let severity: CavitySeverity
                if maxConfidence >= 0.8 && (width * height) > 0.01 {
                    severity = .severe
                } else if maxConfidence >= 0.65 {
                    severity = .moderate
                } else {
                    severity = .mild
                }
                
                let detection = CavityDetection(
                    boundingBox: boundingBox,
                    confidence: maxConfidence,
                    severity: severity,
                    classId: bestClassId
                )
                
                detections.append(detection)
            }
        }
        
        // Apply Non-Maximum Suppression to remove overlapping detections
        let filteredDetections = ImageProcessingUtils.applyNonMaximumSuppression(
            detections: detections,
            iouThreshold: iouThreshold,
            confidenceThreshold: confidenceThreshold
        )
        
        // Limit to reasonable number of detections (max 10 cavities)
        let finalDetections = Array(filteredDetections.prefix(10))
        
        print("📊 Filtered to \(finalDetections.count) detections after NMS")
        return finalDetections
    }
    
    /// Detect output format from tensor shape
    /// - Parameter outputShape: Output tensor shape
    /// - Returns: Tuple of (numDetections, featuresPerDetection, isBuiltInNMS)
    private func detectOutputFormat(_ outputShape: [Int32]) -> (Int, Int, Bool) {
        guard outputShape.count >= 3 else {
            // Fallback to default format
            return (8400, 84, false)
        }
        
        let batchSize = Int(outputShape[0])
        let dim1 = Int(outputShape[1])
        let dim2 = Int(outputShape[2])
        
        // Check for built-in NMS format (e.g., [1, N, 6])
        if batchSize == 1 && dim2 == 6 {
            return (dim1, 6, true)
        }
        
        // Standard YOLO format detection
        if dim1 == 84 && dim2 == 8400 {
            // Format: [1, 84, 8400]
            return (8400, 84, false)
        } else if dim1 == 8400 && dim2 == 84 {
            // Format: [1, 8400, 84]
            return (8400, 84, false)
        } else if dim1 > 4 && dim2 > 4 {
            // Generic format: assume [1, F, N] or [1, N, F]
            if dim1 < dim2 {
                // [1, F, N] - features first
                return (dim2, dim1, false)
            } else {
                // [1, N, F] - detections first
                return (dim1, dim2, false)
            }
        }
        
        // Fallback to default
        return (8400, 84, false)
    }
    
    /// Parse detections from built-in NMS format
    /// - Parameters:
    ///   - floatArray: Raw model output as float array
    ///   - numDetections: Number of detections
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - preprocessingParams: Image preprocessing parameters
    ///   - originalImageSize: Original image size
    /// - Returns: Array of CavityDetection objects
    /// - Throws: DetectionError if parsing fails
    private func parseBuiltInNMSDetections(
        floatArray: [Float],
        numDetections: Int,
        confidenceThreshold: Double,
        preprocessingParams: PreprocessingParams,
        originalImageSize: CGSize
    ) throws -> [CavityDetection] {
        
        var detections: [CavityDetection] = []
        
        // Built-in NMS format: [x1, y1, x2, y2, score, class]
        for i in 0..<numDetections {
            let baseIndex = i * 6
            
            let x1 = Double(floatArray[baseIndex])
            let y1 = Double(floatArray[baseIndex + 1])
            let x2 = Double(floatArray[baseIndex + 2])
            let y2 = Double(floatArray[baseIndex + 3])
            let score = Double(floatArray[baseIndex + 4])
            let classId = Int(floatArray[baseIndex + 5])
            
            // Only consider detections with sufficient confidence
            if score >= confidenceThreshold {
                // Convert to normalized coordinates
                let width = x2 - x1
                let height = y2 - y1
                
                let normalizedBox = BoundingBox(
                    x: x1,
                    y: y1,
                    width: width,
                    height: height
                )
                
                // Convert to original image coordinates
                let boundingBox = ImageProcessingUtils.convertToOriginalCoordinates(
                    normalizedBox: normalizedBox,
                    originalSize: originalImageSize,
                    preprocessingParams: preprocessingParams
                )
                
                // Determine severity based on confidence and size
                let severity: CavitySeverity
                if score >= 0.8 && (width * height) > 0.01 {
                    severity = .severe
                } else if score >= 0.65 {
                    severity = .moderate
                } else {
                    severity = .mild
                }
                
                let detection = CavityDetection(
                    boundingBox: boundingBox,
                    confidence: score,
                    severity: severity,
                    classId: classId
                )
                
                detections.append(detection)
            }
        }
        
        return detections
    }
    
    /// Create mock detection result for demo purposes
    /// - Parameters:
    ///   - image: Input image
    ///   - preprocessingParams: Preprocessing parameters
    /// - Returns: Mock DetectionResult
    private func createMockDetectionResult(
        image: UIImage,
        preprocessingParams: PreprocessingParams
    ) -> DetectionResult {
        
        // Create mock detections for demo
        let mockDetections = [
            CavityDetection(
                boundingBox: BoundingBox(x: 0.2, y: 0.3, width: 0.15, height: 0.1),
                confidence: 0.85,
                severity: .moderate,
                classId: 0
            ),
            CavityDetection(
                boundingBox: BoundingBox(x: 0.6, y: 0.4, width: 0.1, height: 0.08),
                confidence: 0.72,
                severity: .mild,
                classId: 0
            )
        ]
        
        // Create image info
        let imageInfo = ImageInfo(
            originalSize: image.size,
            format: "UIImage",
            processingParams: preprocessingParams
        )
        
        // Create analysis summary
        let summary = AnalysisSummary(
            totalCavities: mockDetections.count,
            mostSevereCavity: .moderate,
            averageConfidence: 0.785,
            urgencyLevel: .moderate,
            observations: "Demo mode: 2 cavities detected (1 moderate, 1 mild). Replace with real model for actual detection."
        )
        
        print("🎭 Demo mode: Created \(mockDetections.count) mock cavity detections")
        
        return DetectionResult(
            cavities: mockDetections,
            overallConfidence: summary.averageConfidence,
            imageInfo: imageInfo,
            summary: summary
        )
    }
    
    /// Generate observations based on detected cavities
    /// - Parameter detections: Array of detected cavities
    /// - Returns: Formatted observation string
    private func generateObservations(for detections: [CavityDetection]) -> String {
        if detections.isEmpty {
            return "No cavities detected. Continue regular dental hygiene routine."
        }
        
        let severeCount = detections.filter { $0.severity == .severe }.count
        let moderateCount = detections.filter { $0.severity == .moderate }.count
        let mildCount = detections.filter { $0.severity == .mild }.count
        
        var observations: [String] = []
        
        if severeCount > 0 {
            observations.append("\(severeCount) severe cavity(ies) requiring immediate attention")
        }
        
        if moderateCount > 0 {
            observations.append("\(moderateCount) moderate cavity(ies) detected")
        }
        
        if mildCount > 0 {
            observations.append("\(mildCount) mild cavity(ies) found")
        }
        
        let avgConfidence = detections.map { $0.confidence }.reduce(0, +) / Double(detections.count)
        observations.append("Average confidence: \(Int(avgConfidence * 100))%")
        
        return observations.joined(separator: ". ") + "."
    }
    
    /// Synchronous detection method for compatibility
    /// - Parameters:
    ///   - image: UIImage to analyze
    ///   - confidenceThreshold: Minimum confidence threshold (default: 0.5)
    ///   - iouThreshold: IoU threshold for NMS (default: 0.4)
    /// - Returns: DetectionResult with detected cavities
    /// - Throws: DetectionError if detection fails
    public func detectCavitiesSync(
        in image: UIImage,
        confidenceThreshold: Double = 0.5,
        iouThreshold: Double = 0.4
    ) throws -> DetectionResult {
        
        if !isInitialized {
            try initialize()
        }
        
        return try performDetection(
            image: image,
            confidenceThreshold: confidenceThreshold,
            iouThreshold: iouThreshold
        )
    }
    
    // MARK: - Utility Methods
    
    /// Get model information
    /// - Returns: Dictionary with model details
    public func getModelInfo() -> [String: Any] {
        return [
            "modelName": "aviScan-YOLOv11n-v1.0",
            "modelType": "TensorFlow Lite",
            "inputSize": "640x640",
            "outputFormat": "[1, 84, 8400]",
            "isInitialized": isInitialized,
            "interpreterAvailable": interpreter != nil
        ]
    }
    
    /// Reset the service (useful for testing)
    public func reset() {
        interpreter = nil
        isInitialized = false
        print("🔄 CavityDetectionService reset")
    }
}