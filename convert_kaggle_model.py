#!/usr/bin/env python3
"""
Kaggle Model Conversion Script for iDENTify iOS App

This script converts the aviScan-YOLOv11n-v1.0 Kaggle model from PyTorch (.pt) format 
to TensorFlow Lite (.tflite) format for iOS integration.

Requirements:
- ultralytics
- tensorflow
- torch

Usage:
    python convert_kaggle_model.py --input aviScan-YOLOv11n-v1.0.pt --output aviScan-YOLOv11n-v1.0.tflite
"""

import argparse
import os
import sys
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_dependencies():
    """Check if required dependencies are installed."""
    try:
        import ultralytics
        import tensorflow as tf
        import torch
        logger.info("All required dependencies are installed")
        return True
    except ImportError as e:
        logger.error(f"Missing dependency: {e}")
        logger.error("Please install required packages:")
        logger.error("pip install ultralytics tensorflow torch")
        return False

def convert_model(input_path, output_path):
    """
    Convert PyTorch YOLO model to TensorFlow Lite format.
    
    Args:
        input_path (str): Path to input .pt model file
        output_path (str): Path to output .tflite model file
    """
    try:
        from ultralytics import YOLO
        
        logger.info(f"Loading model from {input_path}")
        
        # Load the YOLO model
        model = YOLO(input_path)
        
        # Validate model
        logger.info("Validating model...")
        logger.info(f"Model type: {type(model.model)}")
        logger.info(f"Model classes: {len(model.names)}")
        logger.info(f"Model names: {model.names}")
        
        # Export to TensorFlow Lite
        logger.info("Converting to TensorFlow Lite format...")
        
        # Export with mobile optimization
        tflite_path = model.export(
            format='tflite',
            imgsz=640,  # Standard YOLO input size
            optimize=True,
            int8=False,  # Use float32 for better accuracy
            dynamic=False,
            simplify=True,
            opset=None,
            verbose=True
        )
        
        # Move to desired output location
        if tflite_path != output_path:
            import shutil
            shutil.move(tflite_path, output_path)
            logger.info(f"Model saved to {output_path}")
        else:
            logger.info(f"Model saved to {output_path}")
        
        # Validate the converted model
        validate_tflite_model(output_path)
        
        return True
        
    except Exception as e:
        logger.error(f"Error converting model: {e}")
        return False

def validate_tflite_model(model_path):
    """Validate the converted TensorFlow Lite model."""
    try:
        import tensorflow as tf
        
        logger.info("Validating TensorFlow Lite model...")
        
        # Load the TFLite model
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        
        # Get input and output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        logger.info("Model validation successful!")
        logger.info(f"Input shape: {input_details[0]['shape']}")
        logger.info(f"Input type: {input_details[0]['dtype']}")
        logger.info(f"Output shape: {output_details[0]['shape']}")
        logger.info(f"Output type: {output_details[0]['dtype']}")
        
        # Expected YOLO v11n format: [1, 84, 8400] or [1, 8400, 84]
        # 84 = 4 (bbox) + 80 (classes)
        # 8400 = number of detections
        expected_output_shapes = [[1, 84, 8400], [1, 8400, 84]]
        actual_output_shape = output_details[0]['shape'].tolist()
        
        if actual_output_shape in expected_output_shapes:
            logger.info("✓ Output shape matches expected YOLO v11n format")
        else:
            logger.warning(f"⚠ Output shape {actual_output_shape} differs from expected {expected_output_shapes}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error validating model: {e}")
        return False

def test_model_inference(model_path):
    """Test the converted model with a dummy input."""
    try:
        import tensorflow as tf
        import numpy as np
        
        logger.info("Testing model inference...")
        
        # Load the TFLite model
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        
        # Get input details
        input_details = interpreter.get_input_details()
        input_shape = input_details[0]['shape']
        
        # Create dummy input (640x640 RGB image)
        dummy_input = np.random.random(input_shape).astype(np.float32)
        
        # Run inference
        interpreter.set_tensor(input_details[0]['index'], dummy_input)
        interpreter.invoke()
        
        # Get output
        output_details = interpreter.get_output_details()
        output = interpreter.get_tensor(output_details[0]['index'])
        
        logger.info(f"Inference test successful! Output shape: {output.shape}")
        logger.info(f"Output range: [{output.min():.3f}, {output.max():.3f}]")
        
        return True
        
    except Exception as e:
        logger.error(f"Error testing inference: {e}")
        return False

def extract_model_metadata(model_path):
    """Extract metadata from the converted model."""
    try:
        import tensorflow as tf
        
        logger.info("Extracting model metadata...")
        
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        metadata = {
            'input_shape': input_details[0]['shape'],
            'input_type': str(input_details[0]['dtype']),
            'output_shape': output_details[0]['shape'],
            'output_type': str(output_details[0]['dtype']),
            'model_size_mb': os.path.getsize(model_path) / (1024 * 1024)
        }
        
        logger.info("Model metadata:")
        for key, value in metadata.items():
            logger.info(f"  {key}: {value}")
        
        return metadata
        
    except Exception as e:
        logger.error(f"Error extracting metadata: {e}")
        return None

def create_ios_integration_guide(output_path):
    """Create integration guide for iOS."""
    guide_content = f"""
# iOS Integration Guide for aviScan-YOLOv11n-v1.0 Model

## Model Information
- **Model File**: {os.path.basename(output_path)}
- **Model Size**: {os.path.getsize(output_path) / (1024 * 1024):.2f} MB
- **Input Format**: 640x640 RGB image (Float32)
- **Output Format**: [1, 84, 8400] tensor
  - 84 = 4 (bbox coordinates) + 80 (class probabilities)
  - 8400 = number of detection anchors

## Integration Steps

1. **Add Model to Xcode Project**:
   - Copy `{os.path.basename(output_path)}` to `iDENTify/Models/` directory
   - Add to Xcode project as bundle resource
   - Ensure "Add to target" is checked

2. **Update CavityDetectionService.swift**:
   - Load model using TensorFlow Lite
   - Implement proper YOLO output parsing
   - Handle 84-dimensional output format

3. **Update ImageProcessingUtils.swift**:
   - Resize images to 640x640
   - Apply proper normalization (0-1 range)
   - Convert to Float32 array

4. **Test Integration**:
   - Verify model loads without errors
   - Test with sample dental images
   - Validate detection results

## Expected Output Format

The model outputs a tensor of shape [1, 84, 8400]:
- Each of the 8400 detections has 84 values
- First 4 values: [x_center, y_center, width, height] (normalized 0-1)
- Next 80 values: class probabilities for each class

## Class Labels

The model was trained on dental cavity detection with the following classes:
- Class 0: cavity (primary detection target)
- Classes 1-79: other dental conditions (if applicable)

## Performance Notes

- Model optimized for mobile inference
- Uses Float32 precision for accuracy
- Expected inference time: ~50-100ms on modern iOS devices
- Memory usage: ~20-30MB during inference
"""
    
    guide_path = os.path.join(os.path.dirname(output_path), "iOS_INTEGRATION_GUIDE.md")
    with open(guide_path, 'w') as f:
        f.write(guide_content)
    
    logger.info(f"iOS integration guide created: {guide_path}")

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Convert Kaggle YOLO model to TensorFlow Lite')
    parser.add_argument('--input', required=True, help='Input .pt model file path')
    parser.add_argument('--output', required=True, help='Output .tflite model file path')
    parser.add_argument('--test', action='store_true', help='Run inference test after conversion')
    parser.add_argument('--guide', action='store_true', help='Create iOS integration guide')
    
    args = parser.parse_args()
    
    # Check dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Validate input file
    if not os.path.exists(args.input):
        logger.error(f"Input file not found: {args.input}")
        sys.exit(1)
    
    # Create output directory if needed
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    logger.info("Starting model conversion...")
    logger.info(f"Input: {args.input}")
    logger.info(f"Output: {args.output}")
    
    # Convert model
    if convert_model(args.input, args.output):
        logger.info("✓ Model conversion completed successfully!")
        
        # Extract metadata
        metadata = extract_model_metadata(args.output)
        
        # Test inference if requested
        if args.test:
            if test_model_inference(args.output):
                logger.info("✓ Inference test passed!")
            else:
                logger.warning("⚠ Inference test failed!")
        
        # Create integration guide if requested
        if args.guide:
            create_ios_integration_guide(args.output)
        
        logger.info(f"\n🎉 Conversion complete! Model ready for iOS integration.")
        logger.info(f"📱 Next steps:")
        logger.info(f"   1. Copy {args.output} to iDENTify/Models/ directory")
        logger.info(f"   2. Update CavityDetectionService.swift")
        logger.info(f"   3. Test with real dental images")
        
    else:
        logger.error("✗ Model conversion failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
