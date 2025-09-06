# iDENTify Setup Guide

This guide will help you set up the iDENTify project with TensorFlow Lite dependencies and camera permissions.

## Dependency Manager

**Important**: TensorFlow Lite is integrated via CocoaPods (not Swift Package Manager) due to lack of official SPM support. For more information about TensorFlow Lite iOS integration, see the [TensorFlow Lite iOS guide](https://www.tensorflow.org/lite/guide/ios).

**Always open `iDENTify.xcworkspace` after running `pod install`** - never use the `.xcodeproj` file directly.

## Prerequisites

- **Xcode 15.0+** (required for iOS 17.0 deployment target)
- **iOS 17.0+** deployment target
- **CocoaPods** installed on your system

### Installing CocoaPods

If you don't have CocoaPods installed, run:

```bash
sudo gem install cocoapods
```

## Setup Instructions

### 1. Install Dependencies

Navigate to the project directory and install CocoaPods dependencies:

```bash
cd /path/to/iDENTify
pod install
```

This will:
- Download TensorFlow Lite Swift framework
- Generate `iDENTify.xcworkspace` file
- Configure project dependencies

### 2. Open the Workspace

**Important**: After running `pod install`, always open the `.xcworkspace` file instead of the `.xcodeproj` file:

```bash
open iDENTify.xcworkspace
```

Or from Xcode: File → Open → Select `iDENTify.xcworkspace`

### 3. Verify Setup

To ensure everything is working correctly:

1. **Build the project** (⌘+B)
2. **Check that TensorFlow Lite is linked**:
   - Go to Project Navigator
   - Expand `Pods` folder
   - Verify `TensorFlowLiteSwift` is listed
3. **Verify privacy permissions**:
   - Check Project Settings → Info tab
   - Confirm camera and photo library usage descriptions are present

## Project Configuration

### Privacy Permissions

The project is configured with the following privacy usage descriptions:

- **Camera Access**: "This app needs camera access to capture photos of your teeth for cavity detection analysis."
- **Photo Library Access**: "This app needs photo library access to select existing photos of your teeth for cavity detection analysis."

These permissions are automatically added to the app's Info.plist when built.

### Dependencies

- **TensorFlowLiteSwift**: Machine learning framework for iOS
- **Platform**: iOS 17.0+
- **Swift Version**: 5.0

## Troubleshooting

### Common Issues

1. **"No such file or directory" error when opening .xcodeproj**
   - Solution: Always use `.xcworkspace` file after running `pod install`

2. **Build errors related to TensorFlow Lite**
   - Solution: Clean build folder (⌘+Shift+K) and rebuild
   - Ensure you're using the workspace file, not the project file

3. **CocoaPods installation fails**
   - Solution: Update CocoaPods: `sudo gem update cocoapods`
   - Clear CocoaPods cache: `pod cache clean --all`

4. **Privacy permission dialogs not appearing**
   - Solution: Check that the privacy keys are correctly added to build settings
   - Verify the app is running on a physical device (simulator may not show permission dialogs)

### Cleaning Up

If you need to start fresh:

```bash
# Remove CocoaPods files
rm -rf Pods/
rm -rf iDENTify.xcworkspace
rm Podfile.lock

# Reinstall
pod install
```

## Next Steps

After successful setup:

1. The project is ready for TensorFlow Lite model integration
2. Camera functionality can be implemented using iOS camera frameworks
3. Machine learning inference can be added using TensorFlow Lite Swift APIs

## Development Notes

- The project uses auto-generated Info.plist (`GENERATE_INFOPLIST_FILE = YES`)
- Privacy permissions are configured in Xcode build settings
- All CocoaPods-generated files are excluded from version control via `.gitignore`

For more information about TensorFlow Lite on iOS, visit: https://www.tensorflow.org/lite/guide/ios
