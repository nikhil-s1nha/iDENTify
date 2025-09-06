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
/// using the aviScan-YOLOv11n-v1.0 model.
public class CavityDetectionService {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    public static let shared = CavityDetectionService()
    
    /// TensorFlow Lite interpreter
    private var interpreter: Interpreter?
    
    /// Model file name
    private let modelFileName = "aviScan-YOLOv11n-v1.0.tflite"
    
    /// Input tensor details
    private var inputDetails: Tensor?
    
    /// Output tensor details
    private var outputDetails: [Tensor] = []
    
    /// Model configuration
    private let modelConfig = ModelConfiguration()
    
    /// Processing queue for inference operations
    private let processingQueue = DispatchQueue(label: "com.identify.cavity.detection", qos: .userInitiated)
    
    /// Service initialization status
    private var isInitialized = false
    
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
    }
    
    /// Load the TensorFlow Lite model from bundle
    /// - Throws: DetectionError if model loading fails
    private func loadModel() throws {
        let modelName = "aviScan-YOLOv11n-v1.0"
        
        // Try to find model in Models subfolder first, then root
        let modelPath: String
        if let path = Bundle.main.path(forResource: modelName, ofType: "tflite", inDirectory: "Models") {
            modelPath = path
            print("✅ Model found in Models subfolder: \(path)")
        } else if let path = Bundle.main.path(forResource: modelName, ofType: "tflite") {
            modelPath = path
            print("✅ Model found in root directory: \(path)")
        } else {
            print("❌ Model not found in bundle")
            throw DetectionError.modelNotFound
        }
        
        // Verify file exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: modelPath) {
            print("✅ Model file exists at path: \(modelPath)")
        } else {
            print("❌ Model file does not exist at path: \(modelPath)")
            throw DetectionError.modelNotFound
        }
        
        do {
            // Configure interpreter options for optimal performance
            var options = Interpreter.Options()
            options.threadCount = max(1, ProcessInfo.processInfo.activeProcessorCount - 1)
            
            // Optionally add GPU delegate for Metal performance
            #if canImport(TensorFlowLiteCMetal)
            let delegate = MetalDelegate()
            interpreter = try Interpreter(modelPath: modelPath, options: options, delegates: [delegate])
            #else
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            #endif
        } catch {
            throw DetectionError.modelLoadingFailed(error.localizedDescription)
        }
    }
    
    /// Configure the TensorFlow Lite interpreter
    /// - Throws: DetectionError if configuration fails
    private func configureInterpreter() throws {
        guard let interpreter = interpreter else {
            throw DetectionError.modelLoadingFailed("Interpreter not initialized")
        }
        
        do {
            try interpreter.allocateTensors()
            
            // Get input tensor details
            let inputTensorCount = try interpreter.inputTensorCount
            guard inputTensorCount > 0 else {
                throw DetectionError.modelLoadingFailed("No input tensors found")
            }
            
            inputDetails = try interpreter.input(at: 0)
            
            // Validate input tensor shape
            let inputShape = inputDetails?.shape.dimensions
            let expectedShape = [1, Int(modelConfig.inputSize.width), Int(modelConfig.inputSize.height), modelConfig.channels]
            guard inputShape == expectedShape else {
                throw DetectionError.modelLoadingFailed("Input tensor shape mismatch. Expected: \(expectedShape), Got: \(inputShape ?? [])")
            }
            
            // Get output tensor details and validate against expected YOLO export
            let outputTensorCount = try interpreter.outputTensorCount
            outputDetails = []
            
            for i in 0..<outputTensorCount {
                let outputTensor = try interpreter.output(at: i)
                outputDetails.append(outputTensor)
            }
            
            // Validate output tensor metadata against expected YOLO format
            try validateOutputTensorMetadata()
            
        } catch {
            throw DetectionError.modelLoadingFailed(error.localizedDescription)
        }
    }
    
    /// Validate output tensor metadata against expected YOLO export format
    /// - Throws: DetectionError if validation fails
    private func validateOutputTensorMetadata() throws {
        guard !outputDetails.isEmpty else {
            throw DetectionError.modelLoadingFailed("No output tensors found")
        }
        
        // Log tensor information for debugging
        for (index, tensor) in outputDetails.enumerated() {
            print("Output tensor \(index): shape=\(tensor.shape), dataType=\(tensor.dataType)")
        }
        
        // Validate expected YOLO output formats
        if outputDetails.count == 1 {
            // Single tensor format: should be [1, nc+5, n] or [1, n, nc+5]
            let shape = outputDetails[0].shape
            if shape.dimensions.count != 3 {
                throw DetectionError.modelLoadingFailed("Expected 3D output tensor, got \(shape.dimensions.count)D")
            }
            print("Single tensor YOLO format detected: \(shape)")
        } else if outputDetails.count >= 3 {
            // NMS outputs format: boxes, scores, classes, count
            print("NMS outputs format detected with \(outputDetails.count) tensors")
        } else {
            throw DetectionError.modelLoadingFailed("Unexpected output tensor count: \(outputDetails.count)")
        }
    }
    
    // MARK: - Public Interface
    
    /// Detect cavities in a dental image
    /// - Parameters:
    ///   - image: UIImage containing the dental photo
    ///   - confidenceThreshold: Minimum confidence threshold for detections (default: 0.5)
    ///   - iouThreshold: IoU threshold for Non-Maximum Suppression (default: 0.4)
    /// - Returns: DetectionResult containing detected cavities and analysis summary
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
            processingQueue.async {
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
    
    /// Perform cavity detection on a dental image
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
        
        // Preprocess image
        let (pixelBuffer, preprocessingParams) = try ImageProcessingUtils.preprocessImage(image)
        let inputArray = try ImageProcessingUtils.pixelBufferToFloat32Array(pixelBuffer)
        
        // Perform inference
        let rawDetections = try performInference(inputArray: inputArray)
        
        // Parse model output
        let cavities = try parseDetections(
            rawDetections,
            confidenceThreshold: confidenceThreshold,
            iouThreshold: iouThreshold,
            originalImageSize: image.size,
            preprocessingParams: preprocessingParams
        )
        
        // Calculate processing time
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to milliseconds
        
        // Update metadata with processing time
        let cavitiesWithTime = cavities.map { cavity in
            var updatedMetadata = cavity.metadata
            let updatedCavity = CavityDetection(
                boundingBox: cavity.boundingBox,
                confidence: cavity.confidence,
                severity: cavity.severity,
                classId: cavity.classId,
                metadata: DetectionMetadata(
                    modelVersion: updatedMetadata.modelVersion,
                    processingTimeMs: processingTime,
                    preprocessingParams: updatedMetadata.preprocessingParams,
                    notes: updatedMetadata.notes
                )
            )
            return updatedCavity
        }
        
        // Create analysis summary
        let summary = createAnalysisSummary(from: cavitiesWithTime)
        
        // Get image quality metrics
        let qualityMetrics = ImageProcessingUtils.validateImageQuality(image)
        
        // Create image info
        let imageInfo = ImageInfo(
            originalSize: image.size,
            format: "UIImage",
            qualityMetrics: qualityMetrics,
            processingParams: preprocessingParams
        )
        
        // Calculate overall confidence
        let overallConfidence = cavitiesWithTime.isEmpty ? 0.0 : cavitiesWithTime.map { $0.confidence }.reduce(0, +) / Double(cavitiesWithTime.count)
        
        return DetectionResult(
            cavities: cavitiesWithTime,
            overallConfidence: overallConfidence,
            imageInfo: imageInfo,
            summary: summary
        )
    }
    
    /// Perform TensorFlow Lite inference
    /// - Parameter inputArray: Preprocessed input data
    /// - Returns: Raw model output
    /// - Throws: DetectionError if inference fails
    private func performInference(inputArray: [Float32]) throws -> [Float32] {
        guard let interpreter = interpreter,
              let inputDetails = inputDetails else {
            throw DetectionError.modelLoadingFailed("Interpreter not properly initialized")
        }
        
        do {
            // Validate input tensor data type and handle quantization
            let inputTensor = try interpreter.input(at: 0)
            let dataType = inputTensor.dataType
            
            switch dataType {
            case .float32:
                // Direct copy for float32 data
                let inputData = Data(bytes: inputArray, count: inputArray.count * MemoryLayout<Float32>.size)
                try interpreter.copy(inputData, toInputAt: 0)
                
            default:
                throw DetectionError.inferenceFailed("Unsupported input tensor data type: \(dataType)")
            }
            
            // Run inference
            try interpreter.invoke()
            
            // Introspect output tensor shapes and implement correct decode path
            let outputCount = interpreter.outputTensorCount
            let outputs = try (0..<outputCount).map { try interpreter.output(at: $0) }
            let shapes = outputs.map { $0.shape }
            
            // Handle different YOLO output formats
            if outputs.count == 1 {
                // Single output tensor format: [1, nc+5, n] or [1, n, nc+5]
                let outputData = outputs[0]
                let outputArray = outputData.data.withUnsafeBytes { bytes in
                    Array(bytes.bindMemory(to: Float32.self))
                }
                return outputArray
            } else if outputs.count >= 3 {
                // NMS outputs present (boxes, scores, classes, count)
                // For now, return the first output (boxes) and handle NMS in parsing
                let outputData = outputs[0]
                let outputArray = outputData.data.withUnsafeBytes { bytes in
                    Array(bytes.bindMemory(to: Float32.self))
                }
                return outputArray
            } else {
                throw DetectionError.inferenceFailed("Unexpected output tensor count: \(outputs.count)")
            }
            
        } catch {
            throw DetectionError.inferenceFailed(error.localizedDescription)
        }
    }
    
    /// Parse raw model output into cavity detections using shape-driven YOLO/TFLite decoding
    /// - Parameters:
    ///   - rawOutput: Raw model output array
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - iouThreshold: IoU threshold for NMS
    ///   - originalImageSize: Original image dimensions
    ///   - preprocessingParams: Preprocessing parameters including letterbox info
    /// - Returns: Array of parsed cavity detections
    /// - Throws: DetectionError if parsing fails
    private func parseDetections(
        _ rawOutput: [Float32],
        confidenceThreshold: Double,
        iouThreshold: Double,
        originalImageSize: CGSize,
        preprocessingParams: PreprocessingParams
    ) throws -> [CavityDetection] {
        
        // Get output tensor shapes from interpreter introspection
        guard let interpreter = interpreter else {
            throw DetectionError.inferenceFailed("Interpreter not available for shape introspection")
        }
        
        let outputs = try (0..<interpreter.outputTensorCount).map { try interpreter.output(at: $0) }
        let shapes = outputs.map { $0.shape }
        
        print("Output tensor shapes: \(shapes)")
        
        var detections: [CavityDetection] = []
        
        // Branch by output format based on tensor shapes
        if outputs.count == 1 {
            // Single tensor format: [1, nc+5, n] or [1, n, nc+5]
            detections = try parseSingleTensorOutput(
                rawOutput: rawOutput,
                shape: shapes[0].dimensions,
                confidenceThreshold: confidenceThreshold,
                originalImageSize: originalImageSize,
                preprocessingParams: preprocessingParams
            )
        } else if outputs.count >= 3 {
            // NMS tensors format: boxes, scores, classes, count
            detections = try parseNMSTensorOutputs(
                outputs: outputs,
                confidenceThreshold: confidenceThreshold,
                originalImageSize: originalImageSize,
                preprocessingParams: preprocessingParams
            )
        } else {
            throw DetectionError.inferenceFailed("Unexpected output tensor count: \(outputs.count)")
        }
        
        // Apply Non-Maximum Suppression
        let filteredDetections = ImageProcessingUtils.applyNonMaximumSuppression(
            detections: detections,
            iouThreshold: iouThreshold,
            confidenceThreshold: confidenceThreshold
        )
        
        return filteredDetections
    }
    
    /// Parse single tensor YOLO output format
    /// - Parameters:
    ///   - rawOutput: Raw model output array
    ///   - shape: Output tensor shape
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - originalImageSize: Original image dimensions
    ///   - preprocessingParams: Preprocessing parameters including letterbox info
    /// - Returns: Array of parsed cavity detections
    private func parseSingleTensorOutput(
        rawOutput: [Float32],
        shape: [Int],
        confidenceThreshold: Double,
        originalImageSize: CGSize,
        preprocessingParams: PreprocessingParams
    ) throws -> [CavityDetection] {
        
        guard shape.count == 3 else {
            throw DetectionError.inferenceFailed("Expected 3D output tensor, got \(shape.count)D")
        }
        
        let batchSize = shape[0]
        let firstDim = shape[1]
        let secondDim = shape[2]
        
        // Determine format: [1, nc+5, n] or [1, n, nc+5]
        // Look for dimension that matches 5 + number of classes
        let nc = 1 // Number of classes (cavity detection)
        let expectedClassDim = 5 + nc // x, y, w, h, obj + class scores
        
        var detections: [CavityDetection] = []
        
        if firstDim == expectedClassDim {
            // Format: [1, nc+5, n] - transpose to [1, n, nc+5]
            let numDetections = secondDim
            print("Single tensor format [1, \(firstDim), \(secondDim)] detected")
            
            for i in 0..<numDetections {
                let baseIndex = i * firstDim
                
                guard baseIndex + expectedClassDim - 1 < rawOutput.count else { break }
                
                // Parse detection: cx, cy, w, h, obj, class_scores...
                var cx = Double(rawOutput[baseIndex])
                var cy = Double(rawOutput[baseIndex + 1])
                var w = Double(rawOutput[baseIndex + 2])
                var h = Double(rawOutput[baseIndex + 3])
                let obj = Double(rawOutput[baseIndex + 4])
                
                // YOLO output normalization: check if coordinates are in pixels vs normalized
                if max(cx, cy, w, h) > 1.0 {
                    // Normalize pixel coordinates to [0,1] model space
                    cx = cx / Double(modelConfig.inputSize.width)
                    cy = cy / Double(modelConfig.inputSize.height)
                    w = w / Double(modelConfig.inputSize.width)
                    h = h / Double(modelConfig.inputSize.height)
                }
                
                // Parse class scores
                let classScores = Array(rawOutput[(baseIndex + 5)..<(baseIndex + expectedClassDim)])
                
                // Find best class
                let (classId, clsProb) = argmax(classScores)
                let score = obj * clsProb
                
                // Filter by confidence threshold
                guard score >= confidenceThreshold else { continue }
                
                // Convert center coordinates to top-left coordinates
                let x = cx - w / 2.0
                let y = cy - h / 2.0
                
                // Create bounding box (normalized coordinates)
                let boundingBox = BoundingBox(x: x, y: y, width: w, height: h)
                
                // Convert to original image coordinates
                let originalBoundingBox = ImageProcessingUtils.convertToOriginalCoordinates(
                    normalizedBox: boundingBox,
                    originalSize: originalImageSize,
                    preprocessingParams: preprocessingParams
                )
                
                // Determine severity based on confidence and class
                let severity = determineSeverity(confidence: score, classId: classId)
                
                // Create detection metadata
                let metadata = DetectionMetadata(
                    modelVersion: "aviScan-YOLOv11n-v1.0",
                    processingTimeMs: 0.0, // Will be updated by caller
                    preprocessingParams: preprocessingParams
                )
                
                let detection = CavityDetection(
                    boundingBox: originalBoundingBox,
                    confidence: score,
                    severity: severity,
                    classId: classId,
                    metadata: metadata
                )
                
                detections.append(detection)
            }
            
        } else if secondDim == expectedClassDim {
            // Format: [1, n, nc+5] - direct format
            let numDetections = firstDim
            print("Single tensor format [1, \(firstDim), \(secondDim)] detected")
            
            for i in 0..<numDetections {
                let baseIndex = i * secondDim
                
                guard baseIndex + expectedClassDim - 1 < rawOutput.count else { break }
                
                // Parse detection: cx, cy, w, h, obj, class_scores...
                var cx = Double(rawOutput[baseIndex])
                var cy = Double(rawOutput[baseIndex + 1])
                var w = Double(rawOutput[baseIndex + 2])
                var h = Double(rawOutput[baseIndex + 3])
                let obj = Double(rawOutput[baseIndex + 4])
                
                // YOLO output normalization: check if coordinates are in pixels vs normalized
                if max(cx, cy, w, h) > 1.0 {
                    // Normalize pixel coordinates to [0,1] model space
                    cx = cx / Double(modelConfig.inputSize.width)
                    cy = cy / Double(modelConfig.inputSize.height)
                    w = w / Double(modelConfig.inputSize.width)
                    h = h / Double(modelConfig.inputSize.height)
                }
                
                // Parse class scores
                let classScores = Array(rawOutput[(baseIndex + 5)..<(baseIndex + expectedClassDim)])
                
                // Find best class
                let (classId, clsProb) = argmax(classScores)
                let score = obj * clsProb
                
                // Filter by confidence threshold
                guard score >= confidenceThreshold else { continue }
                
                // Convert center coordinates to top-left coordinates
                let x = cx - w / 2.0
                let y = cy - h / 2.0
                
                // Create bounding box (normalized coordinates)
                let boundingBox = BoundingBox(x: x, y: y, width: w, height: h)
                
                // Convert to original image coordinates
                let originalBoundingBox = ImageProcessingUtils.convertToOriginalCoordinates(
                    normalizedBox: boundingBox,
                    originalSize: originalImageSize,
                    preprocessingParams: preprocessingParams
                )
                
                // Determine severity based on confidence and class
                let severity = determineSeverity(confidence: score, classId: classId)
                
                // Create detection metadata
                let metadata = DetectionMetadata(
                    modelVersion: "aviScan-YOLOv11n-v1.0",
                    processingTimeMs: 0.0, // Will be updated by caller
                    preprocessingParams: preprocessingParams
                )
                
                let detection = CavityDetection(
                    boundingBox: originalBoundingBox,
                    confidence: score,
                    severity: severity,
                    classId: classId,
                    metadata: metadata
                )
                
                detections.append(detection)
            }
        } else {
            throw DetectionError.inferenceFailed("Cannot determine YOLO output format from shape: \(shape)")
        }
        
        return detections
    }
    
    /// Parse NMS tensor outputs format
    /// - Parameters:
    ///   - outputs: Array of output tensors
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - originalImageSize: Original image dimensions
    ///   - preprocessingParams: Preprocessing parameters including letterbox info
    /// - Returns: Array of parsed cavity detections
    private func parseNMSTensorOutputs(
        outputs: [Tensor],
        confidenceThreshold: Double,
        originalImageSize: CGSize,
        preprocessingParams: PreprocessingParams
    ) throws -> [CavityDetection] {
        
        // Expect: boxes [1,100,4], scores [1,100], classes [1,100], count [1]
        guard outputs.count >= 4 else {
            throw DetectionError.inferenceFailed("Expected at least 4 NMS output tensors, got \(outputs.count)")
        }
        
        let boxesTensor = outputs[0]
        let scoresTensor = outputs[1]
        let classesTensor = outputs[2]
        let countTensor = outputs[3]
        
        // Read count as Int
        let countData = countTensor.data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int32.self))
        }
        let count = Int(countData[0])
        
        print("NMS format detected with \(count) detections")
        
        // Read boxes, scores, and classes
        let boxesData = boxesTensor.data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float32.self))
        }
        let scoresData = scoresTensor.data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float32.self))
        }
        let classesData = classesTensor.data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int32.self))
        }
        
        var detections: [CavityDetection] = []
        
        for i in 0..<count {
            let boxIndex = i * 4
            let score = Double(scoresData[i])
            let classId = Int(classesData[i])
            
            // Filter by confidence threshold
            guard score >= confidenceThreshold else { continue }
            
            // Parse bounding box: x1, y1, x2, y2
            let x1 = Double(boxesData[boxIndex])
            let y1 = Double(boxesData[boxIndex + 1])
            let x2 = Double(boxesData[boxIndex + 2])
            let y2 = Double(boxesData[boxIndex + 3])
            
            // Convert to x, y, w, h format (normalized)
            let x = x1
            let y = y1
            let w = x2 - x1
            let h = y2 - y1
            
            // Create bounding box (normalized coordinates)
            let boundingBox = BoundingBox(x: x, y: y, width: w, height: h)
            
            // Convert to original image coordinates
            let originalBoundingBox = ImageProcessingUtils.convertToOriginalCoordinates(
                normalizedBox: boundingBox,
                originalSize: originalImageSize,
                preprocessingParams: preprocessingParams
            )
            
            // Determine severity based on confidence and class
            let severity = determineSeverity(confidence: score, classId: classId)
            
            // Create detection metadata
            let metadata = DetectionMetadata(
                modelVersion: "aviScan-YOLOv11n-v1.0",
                processingTimeMs: 0.0, // Will be updated by caller
                preprocessingParams: preprocessingParams
            )
            
            let detection = CavityDetection(
                boundingBox: originalBoundingBox,
                confidence: score,
                severity: severity,
                classId: classId,
                metadata: metadata
            )
            
            detections.append(detection)
        }
        
        return detections
    }
    
    /// Find the index and value of the maximum element in an array
    /// - Parameter array: Array of Float32 values
    /// - Returns: Tuple of (index, value) for the maximum element
    private func argmax(_ array: [Float32]) -> (Int, Double) {
        var maxIndex = 0
        var maxValue = array[0]
        
        for (index, value) in array.enumerated() {
            if value > maxValue {
                maxValue = value
                maxIndex = index
            }
        }
        
        return (maxIndex, Double(maxValue))
    }
    
    /// Determine cavity severity based on confidence and class
    /// - Parameters:
    ///   - confidence: Detection confidence score
    ///   - classId: Detected class ID
    /// - Returns: CavitySeverity level
    private func determineSeverity(confidence: Double, classId: Int) -> CavitySeverity {
        // This is a simplified mapping - in practice, you'd have more sophisticated logic
        // based on the actual model's class definitions
        
        if confidence >= 0.8 {
            return .severe
        } else if confidence >= 0.6 {
            return .moderate
        } else {
            return .mild
        }
    }
    
    /// Create analysis summary from detected cavities
    /// - Parameter cavities: Array of detected cavities
    /// - Returns: AnalysisSummary
    private func createAnalysisSummary(from cavities: [CavityDetection]) -> AnalysisSummary {
        let totalCavities = cavities.count
        let mostSevereCavity = cavities.max { $0.severity.priority < $1.severity.priority }?.severity
        let averageConfidence = cavities.isEmpty ? 0.0 : cavities.map { $0.confidence }.reduce(0, +) / Double(cavities.count)
        
        // Determine urgency level
        let urgencyLevel: UrgencyLevel
        if cavities.isEmpty {
            urgencyLevel = .routine
        } else if mostSevereCavity == .severe {
            urgencyLevel = .urgent
        } else if mostSevereCavity == .moderate {
            urgencyLevel = .moderate
        } else {
            urgencyLevel = .routine
        }
        
        // Generate observations
        let observations: String?
        if cavities.isEmpty {
            observations = "No cavities detected. Continue regular oral hygiene practices."
        } else {
            let severityCounts = cavities.reduce(into: [CavitySeverity: Int]()) { counts, cavity in
                counts[cavity.severity, default: 0] += 1
            }
            
            var observationParts: [String] = []
            for (severity, count) in severityCounts {
                observationParts.append("\(count) \(severity.displayName.lowercased())")
            }
            
            observations = "Detected cavities: " + observationParts.joined(separator: ", ") + ". Consult with a dentist for proper treatment."
        }
        
        return AnalysisSummary(
            totalCavities: totalCavities,
            mostSevereCavity: mostSevereCavity,
            averageConfidence: averageConfidence,
            urgencyLevel: urgencyLevel,
            observations: observations
        )
    }
    
    // MARK: - Utility Methods
    
    /// Check if the service is ready for inference
    /// - Returns: True if service is initialized and ready
    public func isReady() -> Bool {
        return isInitialized && interpreter != nil
    }
    
    /// Get model information
    /// - Returns: Dictionary containing model metadata
    public func getModelInfo() -> [String: Any] {
        guard let inputDetails = inputDetails else {
            return [:]
        }
        
        return [
            "model_name": modelFileName,
            "input_shape": inputDetails.shape,
            "output_count": outputDetails.count,
            "is_initialized": isInitialized
        ]
    }
    
    /// Reset the service (useful for memory management)
    public func reset() {
        interpreter = nil
        inputDetails = nil
        outputDetails = []
        isInitialized = false
    }
}

// MARK: - Model Configuration

/// Configuration for the cavity detection model
private struct ModelConfiguration {
    /// Input image size
    let inputSize = CGSize(width: 640, height: 640)
    
    /// Number of color channels
    let channels = 3
    
    /// Confidence threshold for detections
    let defaultConfidenceThreshold: Double = 0.5
    
    /// IoU threshold for Non-Maximum Suppression
    let defaultIoUThreshold: Double = 0.4
    
    /// Maximum number of detections to return
    let maxDetections: Int = 100
}

// MARK: - Extensions

extension CavityDetectionService {
    
    /// Convenience method for synchronous detection (use with caution on main thread)
    /// - Parameters:
    ///   - image: UIImage to analyze
    ///   - confidenceThreshold: Minimum confidence threshold
    ///   - iouThreshold: IoU threshold for NMS
    /// - Returns: DetectionResult
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
}
