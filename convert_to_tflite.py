#!/usr/bin/env python3
"""
Convert PyTorch cavity detection model to TensorFlow Lite format
"""

import torch
import numpy as np
from ultralytics import YOLO
import os

def convert_pytorch_to_tflite():
    print("🔄 Converting PyTorch cavity detection model to TensorFlow Lite...")
    
    # Load your PyTorch model
    model_path = "cavity_detection_ai/cavity detection.pt"
    if not os.path.exists(model_path):
        print(f"❌ Model file not found: {model_path}")
        return False
    
    try:
        # Load the model
        model = YOLO(model_path)
        print("✅ PyTorch model loaded successfully")
        
        # Export to TensorFlow Lite
        print("🔄 Exporting to TensorFlow Lite...")
        model.export(format='tflite', imgsz=640, optimize=True, int8=False)
        
        # Check if export was successful
        tflite_path = "cavity_detection_ai/cavity detection.tflite"
        if os.path.exists(tflite_path):
            print("✅ TensorFlow Lite export successful")
            
            # Move to the correct location
            target_path = "iDENTify/cavity_detection.tflite"
            os.rename(tflite_path, target_path)
            print(f"✅ Moved to: {target_path}")
            
            # Check file size
            size = os.path.getsize(target_path)
            print(f"📊 Model size: {size / (1024*1024):.1f} MB")
            
            return True
        else:
            print("❌ TensorFlow Lite export failed - file not found")
            return False
            
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        return False

if __name__ == "__main__":
    success = convert_pytorch_to_tflite()
    if success:
        print("🎉 Conversion completed successfully!")
        print("📱 Your app can now use the real AI model!")
    else:
        print("❌ Conversion failed. The app will use mock detection.")
