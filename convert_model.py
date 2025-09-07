#!/usr/bin/env python3
"""
Convert PyTorch YOLO model to TensorFlow Lite for iOS integration
"""

import torch
import numpy as np
from ultralytics import YOLO
import tensorflow as tf
from pathlib import Path

def convert_yolo_to_tflite():
    """Convert YOLO PyTorch model to TensorFlow Lite format"""
    
    print("🔄 Starting YOLO to TensorFlow Lite conversion...")
    
    # Load the YOLO model
    model_path = "cavity_detection_ai/cavity detection.pt"
    print(f"📁 Loading model from: {model_path}")
    
    try:
        # Load YOLO model
        model = YOLO(model_path)
        print("✅ YOLO model loaded successfully")
        
        # Export to TensorFlow Lite
        output_path = "iDENTify/Models/aviScan-YOLOv11n-v1.0.tflite"
        
        print("🔄 Exporting to TensorFlow Lite...")
        model.export(
            format='tflite',
            imgsz=640,  # Standard YOLO input size
            optimize=True,
            int8=False,  # Use float32 for better accuracy
            dynamic=False,
            simplify=True,
            opset=None,
            verbose=True
        )
        
        # Move the exported file to our Models directory
        import shutil
        exported_file = "cavity detection.tflite"
        if Path(exported_file).exists():
            shutil.move(exported_file, output_path)
            print(f"✅ Model exported to: {output_path}")
        else:
            print("❌ Export failed - file not found")
            return False
            
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        return False
    
    # Create labels file
    labels_content = """cavity
normal
cavity
normal"""
    
    with open("iDENTify/Models/labels.txt", "w") as f:
        f.write(labels_content)
    print("✅ Labels file created")
    
    # Create model config
    config_content = """{
    "model_name": "aviScan-YOLOv11n-v1.0",
    "version": "1.0.0",
    "input_size": [640, 640],
    "num_classes": 4,
    "class_names": ["cavity", "normal", "cavity", "normal"],
    "confidence_threshold": 0.5,
    "iou_threshold": 0.4,
    "format": "yolo"
}"""
    
    with open("iDENTify/Models/config.json", "w") as f:
        f.write(config_content)
    print("✅ Config file created")
    
    print("🎉 Conversion completed successfully!")
    return True

if __name__ == "__main__":
    success = convert_yolo_to_tflite()
    if success:
        print("\n🚀 Ready to integrate with iOS app!")
        print("📱 The app will now use real AI detection instead of mock mode.")
    else:
        print("\n❌ Conversion failed. Please check the error messages above.")
