# Camera Implementation Documentation

## Overview

This document describes the camera functionality implementation in the iDENTify iOS app. The implementation provides a clean SwiftUI interface for camera capture and photo library selection using UIKit's `UIImagePickerController` wrapped in a `UIViewControllerRepresentable`.

## Architecture

The camera implementation follows the MVVM (Model-View-ViewModel) architecture pattern with the following components:

### Components

1. **ImagePicker.swift** - SwiftUI wrapper around UIImagePickerController
2. **CameraViewModel.swift** - View model managing camera state and business logic
3. **CameraSourceType.swift** - Enumeration for camera source types
4. **ContentView.swift** - Main view integrating camera functionality

## Implementation Details

### ImagePicker.swift

A SwiftUI wrapper that provides camera and photo library access functionality:

- Conforms to `UIViewControllerRepresentable` protocol
- Includes a `Coordinator` class to handle UIImagePickerController delegate methods
- Supports both camera capture and photo library selection via `sourceType` parameter
- Handles image selection completion with `@Binding` for captured images
- Provides proper dismissal handling for user cancellation

**Key Features:**
- Clean SwiftUI interface for camera functionality
- Automatic dismissal on image selection or cancellation
- Media type restriction to images only (prevents video selection)
- Error handling for camera availability and permissions

### CameraViewModel.swift

A view model that manages camera-related state and business logic:

- Conforms to `ObservableObject` for SwiftUI integration
- Published properties for UI state management:
  - `showingImagePicker`: Controls camera/photo library presentation
  - `selectedImage`: Stores captured/selected images
  - `sourceType`: Chooses between camera and photo library
  - `permissionAlert`: Handles permission-related user alerts
- Methods for handling camera and photo library actions
- Camera availability checking functionality
- Comprehensive permission handling with user-visible guidance

**Key Methods:**
- `openCamera()`: Opens camera for photo capture with permission checking
- `openPhotoLibrary()`: Opens photo library for image selection with permission checking
- `dismissImagePicker()`: Dismisses the image picker
- `clearSelectedImage()`: Clears the selected image

### CameraSourceType.swift

An enumeration defining different camera source types for better type safety:

- `CameraSourceType` enum with cases for `.camera` and `.photoLibrary`
- Computed property to convert to `UIImagePickerController.SourceType`
- Helper methods for checking camera availability
- User-friendly descriptions for each source type

**Key Features:**
- Type-safe way to handle different image source options
- Automatic availability checking
- Clean conversion to UIKit types

### ContentView.swift Integration

The main view integrates camera functionality with the existing UI:

- Added `@StateObject` for CameraViewModel
- Camera access buttons integrated into existing layout:
  - "Take Photo" button for camera capture
  - "Choose from Library" button for photo library selection
- Sheet presentation for the ImagePicker view
- Permission alert handling with user guidance
- Button styling consistent with existing design
- Proper button state management (disabled when unavailable)

## Usage Instructions

### Basic Usage

1. **Camera Capture:**
   ```swift
   cameraViewModel.openCamera()
   ```

2. **Photo Library Selection:**
   ```swift
   cameraViewModel.openPhotoLibrary()
   ```

3. **Accessing Selected Image:**
   ```swift
   if let image = cameraViewModel.selectedImage {
       // Use the selected image
   }
   ```

### Integration Pattern

The camera functionality is integrated using SwiftUI's sheet presentation:

```swift
.sheet(isPresented: $cameraViewModel.showingImagePicker) {
    ImagePicker(
        selectedImage: $cameraViewModel.selectedImage,
        sourceType: cameraViewModel.sourceType.uiSourceType
    )
}
```

## State Management

The implementation uses SwiftUI's declarative state management:

- `@StateObject` for the CameraViewModel instance
- `@Published` properties for reactive UI updates
- `@Binding` for two-way data flow between views
- Automatic UI updates when state changes

## Navigation Flow

1. User taps "Take Photo" or "Choose from Library"
2. CameraViewModel updates sourceType and shows ImagePicker
3. ImagePicker presents UIImagePickerController
4. User captures/selects image or cancels
5. ImagePicker updates selectedImage and dismisses
6. ContentView receives updated image and can navigate to next screen

## Privacy Permissions

The app requires the following privacy permissions in Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture photos for dental analysis.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images for dental analysis.</string>
```

## Error Handling

The implementation includes comprehensive error handling:

- Camera availability checking before presenting camera
- Photo library availability checking
- Permission status checking using `AVCaptureDevice.authorizationStatus(for:)` and `PHPhotoLibrary.authorizationStatus()`
- User-visible permission alerts with Settings navigation
- Graceful handling of permission denials with actionable user guidance
- Automatic fallback when features are unavailable
- Media type restriction to prevent video selection edge cases

## Troubleshooting

### Common Issues

1. **Camera Not Available:**
   - Check if running on simulator (camera not available)
   - Verify device has camera hardware
   - Check camera permissions

2. **Photo Library Not Available:**
   - Verify photo library permissions
   - Check device storage availability

3. **Build Errors:**
   - Ensure all new files are added to Xcode project
   - Verify file references in project.pbxproj
   - Check import statements

### Debug Tips

- Use `CameraSourceType.camera.isAvailable` to check camera availability
- Use `CameraSourceType.photoLibrary.isAvailable` to check photo library availability
- Monitor console for permission-related messages
- Test on physical device for camera functionality

## Future Enhancements

The current implementation provides a solid foundation for future enhancements:

- Custom camera UI with advanced controls
- Image editing capabilities
- Batch image processing
- Integration with TensorFlow Lite models
- Real-time image analysis

## Code Examples

### Custom ImagePicker Usage

```swift
struct CustomImageView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    
    var body: some View {
        VStack {
            if let image = cameraViewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            Button("Take Photo") {
                cameraViewModel.openCamera()
            }
        }
        .sheet(isPresented: $cameraViewModel.showingImagePicker) {
            ImagePicker(
                selectedImage: $cameraViewModel.selectedImage,
                sourceType: cameraViewModel.sourceType.uiSourceType
            )
        }
    }
}
```

### Checking Availability

```swift
if CameraSourceType.camera.isAvailable {
    // Camera is available
    cameraViewModel.openCamera()
} else {
    // Show alternative UI or error message
}
```

This implementation provides a robust, maintainable, and user-friendly camera integration that follows iOS development best practices and SwiftUI patterns.
