import SwiftUI
import UIKit
import AVFoundation
import Photos

/// Alert item for permission-related alerts
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
}

/// View model for managing camera-related state and business logic
@MainActor
class CameraViewModel: ObservableObject {
    @Published var showingImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var sourceType: CameraSourceType = .camera
    @Published var permissionAlert: AlertItem?
    @Published var validationAlert: AlertItem?
    
    // Navigation state management
    @Published var showingImagePreview = false
    @Published var isAnalyzing = false
    @Published var currentNavigationState: NavigationState = .main
    
    // ML Analysis results
    @Published var detectionResult: DetectionResult?
    @Published var analysisError: DetectionError?
    @Published var showingResults = false
    
    /// Optional closure called when an image is picked
    var onImagePicked: ((UIImage) -> Void)?
    
    /// Opens the camera for photo capture
    func openCamera() {
        guard CameraSourceType.camera.isAvailable else {
            print("Camera is not available on this device")
            return
        }
        
        // Check camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .authorized:
            sourceType = .camera
            showingImagePicker = true
        case .denied, .restricted:
            permissionAlert = AlertItem(
                title: "Camera Access Denied",
                message: "Please enable camera access in Settings to take photos.",
                primaryButton: .default(Text("Settings")) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                },
                secondaryButton: .cancel()
            )
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.sourceType = .camera
                        self.showingImagePicker = true
                    } else {
                        self.permissionAlert = AlertItem(
                            title: "Camera Access Denied",
                            message: "Please enable camera access in Settings to take photos.",
                            primaryButton: .default(Text("Settings")) {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    /// Opens the photo library for image selection
    func openPhotoLibrary() {
        guard CameraSourceType.photoLibrary.isAvailable else {
            print("Photo library is not available on this device")
            return
        }
        
        // Check photo library permission
        let photoStatus = PHPhotoLibrary.authorizationStatus()
        switch photoStatus {
        case .authorized, .limited:
            sourceType = .photoLibrary
            showingImagePicker = true
        case .denied, .restricted:
            permissionAlert = AlertItem(
                title: "Photo Library Access Denied",
                message: "Please enable photo library access in Settings to select photos.",
                primaryButton: .default(Text("Settings")) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                },
                secondaryButton: .cancel()
            )
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        self.sourceType = .photoLibrary
                        self.showingImagePicker = true
                    case .denied, .restricted:
                        self.permissionAlert = AlertItem(
                            title: "Photo Library Access Denied",
                            message: "Please enable photo library access in Settings to select photos.",
                            primaryButton: .default(Text("Settings")) {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    @unknown default:
                        break
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    /// Dismisses the image picker
    func dismissImagePicker() {
        showingImagePicker = false
    }
    
    /// Handles image validation failure
    func handleValidationFailure() {
        validationAlert = AlertItem(
            title: "Image Too Small",
            message: "Please select a larger image for better analysis quality. The image should be at least 100x100 pixels.",
            primaryButton: .default(Text("OK")),
            secondaryButton: nil
        )
    }
    
    /// Clears the selected image
    func clearSelectedImage() {
        selectedImage = nil
    }
    
    /// Handles image selection and calls the onImagePicked closure if set
    func handleImageSelection(_ image: UIImage) {
        resetAnalysis()
        navigateToPreview()
    }
    
    /// Checks if camera is available on the device
    var isCameraAvailable: Bool {
        CameraSourceType.camera.isAvailable
    }
    
    /// Checks if photo library is available on the device
    var isPhotoLibraryAvailable: Bool {
        CameraSourceType.photoLibrary.isAvailable
    }
    
    // MARK: - Navigation Methods
    
    /// Navigates to the image preview screen
    func navigateToPreview() {
        guard selectedImage != nil else { return }
        showingImagePreview = true
        currentNavigationState = .imagePreview
    }
    
    /// Returns to camera for retaking photo
    func retakePhoto() {
        showingImagePreview = false
        currentNavigationState = .main
        clearSelectedImage()
        dismissImagePicker()
        
        // Reopen camera after navigation pop completes
        DispatchQueue.main.async {
            self.openCamera()
        }
    }
    
    /// Initiates image analysis using CavityDetectionService
    func analyzeImage() {
        guard !isAnalyzing else { return }
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        analysisError = nil
        currentNavigationState = .analysis
        
        Task {
            do {
                let result = try await CavityDetectionService.shared.detectCavities(in: image)
                
                self.detectionResult = result
                self.isAnalyzing = false
                self.navigateToResults()
            } catch {
                self.analysisError = error as? DetectionError ?? DetectionError.unknownError(error.localizedDescription)
                self.isAnalyzing = false
            }
        }
    }
    
    /// Navigates to the results screen
    func navigateToResults() {
        guard detectionResult != nil else { return }
        showingResults = true
        currentNavigationState = .results
    }
    
    /// Resets analysis state and clears results
    func resetAnalysis() {
        detectionResult = nil
        analysisError = nil
        isAnalyzing = false
        showingResults = false
    }
    
    /// Retries analysis after an error
    func retryAnalysis() {
        analysisError = nil
        analyzeImage()
    }
    
    /// Resets navigation to main screen
    func resetNavigation() {
        showingImagePreview = false
        isAnalyzing = false
        showingResults = false
        currentNavigationState = .main
        clearSelectedImage()
        dismissImagePicker()
        resetAnalysis()
    }
}
