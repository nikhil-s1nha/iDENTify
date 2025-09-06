import Foundation
import UIKit

/// Enumeration defining different camera source types for image capture
enum CameraSourceType {
    case camera
    case photoLibrary
    
    /// Converts the enum case to UIImagePickerController.SourceType
    var uiSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera:
            return .camera
        case .photoLibrary:
            return .photoLibrary
        }
    }
    
    /// Checks if the camera is available on the device
    var isAvailable: Bool {
        switch self {
        case .camera:
            return UIImagePickerController.isSourceTypeAvailable(.camera)
        case .photoLibrary:
            return UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
        }
    }
    
    /// Returns a user-friendly description of the source type
    var description: String {
        switch self {
        case .camera:
            return "Camera"
        case .photoLibrary:
            return "Photo Library"
        }
    }
}
