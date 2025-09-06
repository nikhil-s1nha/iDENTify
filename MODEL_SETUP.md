# Model Setup Guide: aviScan-YOLOv11n-v1.0

This guide provides step-by-step instructions for downloading the aviScan-YOLOv11n-v1.0 model from Kaggle and converting it to TensorFlow Lite format for iOS integration.

## Overview

The aviScan-YOLOv11n-v1.0 model is a YOLOv11n-based cavity detection model designed for dental image analysis. This guide covers the complete process from downloading the model to integrating it into the iOS app.

## Prerequisites

- Python 3.8 or higher
- Kaggle account with API access
- Xcode 14.0 or higher
- iOS 15.0 or higher target

## Step 1: Kaggle Account Setup

1. **Create Kaggle Account**
   - Visit [kaggle.com](https://www.kaggle.com) and create an account
   - Verify your email address

2. **Enable API Access**
   - Go to your Kaggle account settings
   - Navigate to "API" section
   - Click "Create New API Token"
   - Download the `kaggle.json` file

3. **Install Kaggle API**
   ```bash
   pip install kaggle
   ```

4. **Configure API Credentials**
   ```bash
   mkdir -p ~/.kaggle
   cp kaggle.json ~/.kaggle/
   chmod 600 ~/.kaggle/kaggle.json
   ```

## Step 2: Model Download

1. **Access the Model Page**
   - Visit the aviScan-YOLOv11n-v1.0 dataset page on Kaggle
   - Ensure you have access to the dataset (may require joining a competition or accepting terms)

2. **Download Using Python Script**
   ```bash
   cd Scripts
   export KAGGLE_DATASET="owner/dataset-slug"  # Set the actual dataset identifier
   python download_and_convert_model.py
   ```

   The script will:
   - Download the model files from Kaggle
   - Convert the PyTorch model (.pt) to TensorFlow Lite (.tflite)
   - Optimize the model for mobile deployment
   - Place the converted model in the appropriate directory

## Step 3: Model Conversion Process

The conversion process involves several steps:

1. **Load YOLOv11n Model**
   - Load the downloaded .pt file using Ultralytics
   - Verify model architecture and weights

2. **Export to TensorFlow Lite**
   - Use Ultralytics export functionality
   - Export as Float32 for iOS compatibility
   - Validate the converted model

3. **Model Optimization**
   - Use Float32 precision for compatibility with iOS TensorFlow Lite
   - Optimize for inference speed
   - Validate accuracy preservation

## Step 4: Xcode Integration

1. **Add Model to Project**
   - Copy the converted `aviScan-YOLOv11n-v1.0.tflite` file to `iDENTify/Models/`
   - Add the file to Xcode project as a bundle resource
   - Ensure "Add to target" is checked for the main app target

2. **Verify Bundle Inclusion**
   - Build the project
   - Check that the model file is included in the app bundle
   - Verify file size and permissions

## Model Specifications

### Input Format
- **Image Size**: 640x640 pixels
- **Color Format**: RGB
- **Data Type**: Float32
- **Normalization**: Values normalized to [0, 1] range
- **Batch Size**: 1
- **Aspect Ratio**: Maintained with letterbox padding

### Output Format
- **Detection Format**: YOLO format with shape-driven decoding
- **Single Tensor Format**: [1, nc+5, n] or [1, n, nc+5] where nc=1 (cavity class)
- **NMS Tensor Format**: boxes [1,100,4], scores [1,100], classes [1,100], count [1]
- **Classes**: Cavity detection classes (1 class: cavity)
- **Confidence Threshold**: 0.5 (configurable)
- **NMS Threshold**: 0.4 (configurable)
- **Export Path**: Use `nms=True` for NMS format, or single tensor for raw detections

### Performance Metrics
- **Model Size**: ~6.2 MB (Float32)
- **Inference Time**: ~50-100ms on iPhone 12+
- **Memory Usage**: ~20-30 MB during inference
- **Threading**: Multi-threaded inference with optional Metal GPU acceleration

## Troubleshooting

### Common Issues

1. **Kaggle API Authentication Error**
   ```
   Solution: Verify kaggle.json is in ~/.kaggle/ with correct permissions
   ```

2. **Model Conversion Fails**
   ```
   Solution: Ensure Ultralytics version >= 8.0.0
   Check PyTorch compatibility
   ```

3. **TensorFlow Lite Loading Error**
   ```
   Solution: Verify model file is in app bundle
   Check model compatibility with TensorFlow Lite version
   ```

4. **Inference Performance Issues**
   ```
   Solution: Enable GPU delegate if available
   Consider model quantization level
   ```

### Validation Steps

1. **Model Integrity Check**
   ```python
   import tensorflow as tf
   interpreter = tf.lite.Interpreter(model_path="model.tflite")
   interpreter.allocate_tensors()
   ```

2. **Input/Output Verification**
   - Check input tensor shape: [1, 640, 640, 3]
   - Verify output tensor dimensions
   - Test with sample dental image

3. **Performance Benchmarking**
   - Measure inference time on target device
   - Monitor memory usage during inference
   - Validate detection accuracy

## File Structure

After successful setup, your project should have:

```
iDENTify/
├── Models/
│   └── aviScan-YOLOv11n-v1.0.tflite
├── Services/
│   └── CavityDetectionService.swift
├── Models/
│   └── CavityDetectionModels.swift
├── Utilities/
│   └── ImageProcessingUtils.swift
└── Scripts/
    ├── download_and_convert_model.py
    └── requirements.txt
```

## Next Steps

1. **Test Model Integration**
   - Run the app on a physical device
   - Test with sample dental images
   - Verify detection accuracy

2. **Performance Optimization**
   - Profile inference performance
   - Optimize image preprocessing
   - Consider model quantization levels

3. **User Interface Integration**
   - Integrate detection results with UI
   - Add confidence visualization
   - Implement result export functionality

## Support

For issues related to:
- **Kaggle API**: Check Kaggle documentation
- **Model Conversion**: Refer to Ultralytics documentation
- **iOS Integration**: Check TensorFlow Lite Swift documentation
- **Project-specific**: Review project documentation and code comments

## Version Information

- **Model Version**: aviScan-YOLOv11n-v1.0
- **Ultralytics Version**: 8.0.0+
- **TensorFlow Lite Version**: 2.13.0+
- **iOS Target**: 15.0+
- **Xcode Version**: 14.0+
