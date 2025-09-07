#!/bin/bash

# integrate_kaggle_model.sh
# Automation script for converting and integrating aviScan-YOLOv11n-v1.0 Kaggle model
# into the iDENTify iOS application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MODEL_NAME="aviScan-YOLOv11n-v1.0"
INPUT_MODEL="${MODEL_NAME}.pt"
OUTPUT_MODEL="${MODEL_NAME}.tflite"
IOS_MODEL_DIR="iDENTify/Models"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Python dependencies
check_python_dependencies() {
    print_status "Checking Python dependencies..."
    
    local missing_deps=()
    
    if ! python3 -c "import ultralytics" 2>/dev/null; then
        missing_deps+=("ultralytics")
    fi
    
    if ! python3 -c "import tensorflow" 2>/dev/null; then
        missing_deps+=("tensorflow")
    fi
    
    if ! python3 -c "import torch" 2>/dev/null; then
        missing_deps+=("torch")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warning "Missing Python dependencies: ${missing_deps[*]}"
        print_status "Installing missing dependencies..."
        
        for dep in "${missing_deps[@]}"; do
            print_status "Installing $dep..."
            pip3 install "$dep"
        done
        
        print_success "Python dependencies installed successfully"
    else
        print_success "All Python dependencies are available"
    fi
}

# Function to setup environment
setup_environment() {
    print_status "Setting up environment..."
    
    # Check if we're in the right directory
    if [ ! -f "Podfile" ]; then
        print_error "Podfile not found. Please run this script from the iDENTify project root."
        exit 1
    fi
    
    # Create Models directory if it doesn't exist
    if [ ! -d "$IOS_MODEL_DIR" ]; then
        print_status "Creating Models directory..."
        mkdir -p "$IOS_MODEL_DIR"
    fi
    
    print_success "Environment setup complete"
}

# Function to download model (placeholder)
download_model() {
    print_status "Checking for model file..."
    
    if [ ! -f "$INPUT_MODEL" ]; then
        print_warning "Model file $INPUT_MODEL not found in current directory"
        print_status "Please download the aviScan-YOLOv11n-v1.0.pt model from Kaggle and place it in the project root"
        print_status "You can download it from: https://www.kaggle.com/datasets/your-dataset"
        print_status "Or place the model file manually and run this script again"
        
        read -p "Press Enter after placing the model file, or Ctrl+C to exit..."
        
        if [ ! -f "$INPUT_MODEL" ]; then
            print_error "Model file still not found. Please ensure $INPUT_MODEL is in the project root."
            exit 1
        fi
    fi
    
    print_success "Model file found: $INPUT_MODEL"
}

# Function to convert model
convert_model() {
    print_status "Converting PyTorch model to TensorFlow Lite..."
    
    # Check if conversion script exists
    if [ ! -f "convert_kaggle_model.py" ]; then
        print_error "convert_kaggle_model.py not found. Please ensure the conversion script is in the project root."
        exit 1
    fi
    
    # Run conversion
    python3 convert_kaggle_model.py \
        --input "$INPUT_MODEL" \
        --output "$OUTPUT_MODEL" \
        --test \
        --guide
    
    if [ $? -eq 0 ]; then
        print_success "Model conversion completed successfully"
    else
        print_error "Model conversion failed"
        exit 1
    fi
}

# Function to validate converted model
validate_model() {
    print_status "Validating converted model..."
    
    if [ ! -f "$OUTPUT_MODEL" ]; then
        print_error "Converted model file not found: $OUTPUT_MODEL"
        exit 1
    fi
    
    # Check file size (should be reasonable for a mobile model)
    local file_size=$(stat -f%z "$OUTPUT_MODEL" 2>/dev/null || stat -c%s "$OUTPUT_MODEL" 2>/dev/null)
    local file_size_mb=$((file_size / 1024 / 1024))
    
    print_status "Model file size: ${file_size_mb}MB"
    
    if [ $file_size_mb -gt 100 ]; then
        print_warning "Model file is quite large (${file_size_mb}MB). Consider optimization for mobile deployment."
    fi
    
    print_success "Model validation complete"
}

# Function to integrate with iOS project
integrate_ios() {
    print_status "Integrating model with iOS project..."
    
    # Copy model to iOS Models directory
    cp "$OUTPUT_MODEL" "$IOS_MODEL_DIR/"
    print_success "Model copied to $IOS_MODEL_DIR/$OUTPUT_MODEL"
    
    # Update Podfile if needed
    if grep -q "PyTorchMobile" Podfile; then
        print_warning "PyTorchMobile found in Podfile. Please update Podfile to remove PyTorch dependencies."
        print_status "The Podfile has been updated to use only TensorFlow Lite."
    fi
    
    # Install/update CocoaPods
    if command_exists pod; then
        print_status "Updating CocoaPods dependencies..."
        pod install
        print_success "CocoaPods dependencies updated"
    else
        print_warning "CocoaPods not found. Please install CocoaPods and run 'pod install' manually."
    fi
    
    print_success "iOS integration complete"
}

# Function to run tests
run_tests() {
    print_status "Running integration tests..."
    
    # Test model loading
    python3 -c "
import tensorflow as tf
try:
    interpreter = tf.lite.Interpreter(model_path='$OUTPUT_MODEL')
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print(f'✓ Model loads successfully')
    print(f'✓ Input shape: {input_details[0][\"shape\"]}')
    print(f'✓ Output shape: {output_details[0][\"shape\"]}')
except Exception as e:
    print(f'✗ Model test failed: {e}')
    exit(1)
"
    
    if [ $? -eq 0 ]; then
        print_success "Model tests passed"
    else
        print_error "Model tests failed"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    
    # Remove any temporary files created during conversion
    rm -f temp_*.tflite
    rm -f temp_*.pt
    
    print_success "Cleanup complete"
}

# Function to display next steps
show_next_steps() {
    print_success "🎉 Integration complete!"
    echo
    print_status "Next steps:"
    echo "1. Open iDENTify.xcworkspace (not .xcodeproj) in Xcode"
    echo "2. Add $OUTPUT_MODEL to the Xcode project if not already added"
    echo "3. Ensure the model file is included in the app target"
    echo "4. Build and run the app to test cavity detection"
    echo "5. Test with real dental images"
    echo
    print_status "Model information:"
    echo "• Model file: $IOS_MODEL_DIR/$OUTPUT_MODEL"
    echo "• Input size: 640x640 RGB"
    echo "• Output format: [1, 84, 8400]"
    echo "• Framework: TensorFlow Lite"
    echo
    print_status "For troubleshooting, see KAGGLE_MODEL_INTEGRATION.md"
}

# Main execution
main() {
    echo "=========================================="
    echo "  aviScan-YOLOv11n-v1.0 Integration Script"
    echo "=========================================="
    echo
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Run integration steps
    setup_environment
    check_python_dependencies
    download_model
    convert_model
    validate_model
    integrate_ios
    run_tests
    cleanup
    show_next_steps
    
    echo
    print_success "Integration script completed successfully!"
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
