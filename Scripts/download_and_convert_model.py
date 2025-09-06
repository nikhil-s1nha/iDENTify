#!/usr/bin/env python3
"""
Model Download and Conversion Script for aviScan-YOLOv11n-v1.0

This script downloads the aviScan-YOLOv11n-v1.0 model from Kaggle and converts it
to TensorFlow Lite format for iOS integration.

Requirements:
- Kaggle API credentials configured
- Python 3.8+
- Required packages from requirements.txt

Usage:
    python download_and_convert_model.py

Output:
    - Downloads model files from Kaggle
    - Converts PyTorch model to TensorFlow Lite
    - Places converted model in iDENTify/Models/ directory
"""

import os
import sys
import json
import logging
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any

import kaggle
import torch
from ultralytics import YOLO
import tensorflow as tf
import numpy as np
from PIL import Image

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ModelDownloader:
    """Handles downloading and conversion of the aviScan-YOLOv11n-v1.0 model."""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent  # .../iDENTify/iDENTify
        self.models_dir = self.project_root / "Models"    # not /"iDENTify"/"Models"
        self.scripts_dir = self.project_root / "Scripts"
        self.temp_dir = self.scripts_dir / "temp"
        
        # Model configuration
        self.model_name = "aviScan-YOLOv11n-v1.0"
        self.kaggle_dataset = os.getenv("KAGGLE_DATASET", "<owner>/<dataset-slug>")  # Make configurable
        self.output_model_name = "aviScan-YOLOv11n-v1.0.tflite"
        
        # Create necessary directories
        self._create_directories()
    
    def _create_directories(self):
        """Create necessary directories for the conversion process."""
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Created directories: {self.models_dir}, {self.temp_dir}")
    
    def check_kaggle_credentials(self) -> bool:
        """Check if Kaggle API credentials are properly configured."""
        try:
            kaggle.api.authenticate()
            logger.info("Kaggle API credentials verified")
            return True
        except Exception as e:
            logger.error(f"Kaggle API authentication failed: {e}")
            logger.error("Please ensure kaggle.json is in ~/.kaggle/ directory")
            return False
    
    def download_model(self) -> bool:
        """Download the model from Kaggle."""
        try:
            # Validate dataset identifier
            if self.kaggle_dataset == "<owner>/<dataset-slug>":
                logger.error("Kaggle dataset identifier not configured. Please set KAGGLE_DATASET environment variable.")
                logger.error("Example: export KAGGLE_DATASET='owner/dataset-slug'")
                return False
            
            logger.info(f"Downloading {self.model_name} from Kaggle dataset: {self.kaggle_dataset}")
            
            # Download dataset files
            kaggle.api.dataset_download_files(
                self.kaggle_dataset,
                path=str(self.temp_dir),
                unzip=True
            )
            
            logger.info("Model downloaded successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to download model: {e}")
            logger.error("Please verify the dataset identifier and your Kaggle API access.")
            return False
    
    def find_model_file(self) -> Optional[Path]:
        """Find the downloaded model file (.pt format)."""
        model_files = list(self.temp_dir.glob("*.pt"))
        
        if not model_files:
            logger.error("No .pt model files found in downloaded dataset")
            return None
        
        # Use the first .pt file found (assuming single model)
        model_file = model_files[0]
        logger.info(f"Found model file: {model_file}")
        return model_file
    
    def convert_to_tflite(self, model_path: Path) -> bool:
        """Convert PyTorch model to TensorFlow Lite format."""
        try:
            logger.info("Loading YOLOv11n model...")
            
            # Load the YOLO model
            model = YOLO(str(model_path))
            
            # Export to TensorFlow Lite with optimization
            logger.info("Converting to TensorFlow Lite...")
            tflite_path = model.export(
                format='tflite',
                imgsz=640,
                int8=False,  # Use float32 for compatibility with iOS implementation
                verbose=True
            )
            
            # Move the converted model to the models directory
            converted_model_path = Path(tflite_path)
            target_path = self.models_dir / self.output_model_name
            
            if converted_model_path.exists():
                converted_model_path.rename(target_path)
                logger.info(f"Model converted and saved to: {target_path}")
                return True
            else:
                logger.error("TensorFlow Lite conversion failed")
                return False
                
        except Exception as e:
            logger.error(f"Model conversion failed: {e}")
            return False
    
    def validate_tflite_model(self, model_path: Path) -> bool:
        """Validate the converted TensorFlow Lite model."""
        try:
            logger.info("Validating TensorFlow Lite model...")
            
            # Load the TensorFlow Lite model
            interpreter = tf.lite.Interpreter(model_path=str(model_path))
            interpreter.allocate_tensors()
            
            # Get input and output details
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()
            
            logger.info("Model validation successful")
            logger.info(f"Input shape: {input_details[0]['shape']}")
            logger.info(f"Output details: {len(output_details)} output tensors")
            
            # Test with dummy input
            input_shape = input_details[0]['shape']
            dummy_input = np.random.random(input_shape).astype(np.float32)
            
            interpreter.set_tensor(input_details[0]['index'], dummy_input)
            interpreter.invoke()
            
            logger.info("Model inference test passed")
            return True
            
        except Exception as e:
            logger.error(f"Model validation failed: {e}")
            return False
    
    def cleanup_temp_files(self):
        """Clean up temporary files."""
        try:
            import shutil
            if self.temp_dir.exists():
                shutil.rmtree(self.temp_dir)
                logger.info("Temporary files cleaned up")
        except Exception as e:
            logger.warning(f"Failed to cleanup temp files: {e}")
    
    def get_model_info(self, model_path: Path) -> Dict[str, Any]:
        """Get information about the converted model."""
        try:
            interpreter = tf.lite.Interpreter(model_path=str(model_path))
            interpreter.allocate_tensors()
            
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()
            
            model_size = model_path.stat().st_size / (1024 * 1024)  # Size in MB
            
            return {
                "model_path": str(model_path),
                "model_size_mb": round(model_size, 2),
                "input_shape": input_details[0]['shape'],
                "output_count": len(output_details),
                "input_type": input_details[0]['dtype'].__name__,
                "optimized": True
            }
        except Exception as e:
            logger.error(f"Failed to get model info: {e}")
            return {}
    
    def run_conversion(self) -> bool:
        """Run the complete model download and conversion process."""
        logger.info("Starting model download and conversion process...")
        
        # Step 1: Check Kaggle credentials
        if not self.check_kaggle_credentials():
            return False
        
        # Step 2: Download model
        if not self.download_model():
            return False
        
        # Step 3: Find model file
        model_file = self.find_model_file()
        if not model_file:
            return False
        
        # Step 4: Convert to TensorFlow Lite
        if not self.convert_to_tflite(model_file):
            return False
        
        # Step 5: Validate converted model
        target_model_path = self.models_dir / self.output_model_name
        if not self.validate_tflite_model(target_model_path):
            return False
        
        # Step 6: Get model information
        model_info = self.get_model_info(target_model_path)
        if model_info:
            logger.info("Model conversion completed successfully!")
            logger.info(f"Model size: {model_info['model_size_mb']} MB")
            logger.info(f"Input shape: {model_info['input_shape']}")
            logger.info(f"Model saved to: {model_info['model_path']}")
        
        # Step 7: Cleanup
        self.cleanup_temp_files()
        
        return True

def check_dependencies():
    """Check if all required dependencies are installed."""
    required_packages = [
        'kaggle', 'torch', 'ultralytics', 'tensorflow', 'numpy', 'PIL'
    ]
    
    missing_packages = []
    for package in required_packages:
        try:
            if package == 'PIL':
                import PIL
            else:
                __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        logger.error(f"Missing required packages: {missing_packages}")
        logger.error("Please install them using: pip install -r requirements.txt")
        return False
    
    return True

def main():
    """Main function to run the model download and conversion."""
    logger.info("=== aviScan-YOLOv11n-v1.0 Model Download and Conversion ===")
    
    # Check dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Create downloader instance
    downloader = ModelDownloader()
    
    # Run conversion process
    success = downloader.run_conversion()
    
    if success:
        logger.info("✅ Model download and conversion completed successfully!")
        logger.info("The model is ready for iOS integration.")
        logger.info(f"Model location: {downloader.models_dir / downloader.output_model_name}")
    else:
        logger.error("❌ Model download and conversion failed!")
        logger.error("Please check the error messages above and try again.")
        sys.exit(1)

if __name__ == "__main__":
    main()
