import os
from ultralytics import YOLO

if __name__ == "__main__":
    # Set model parameters
    model_name = r'yolo11n.pt'  # Path to YOLOv8n model

    # Load the YOLO model
    model = YOLO(model_name)

    # Train the model with the YAML data configuration for Customer Monitoring
    results = model.train(
        data=r'data.yaml',  # Path to the YAML file for Customer Monitoring
        epochs=100,               # Number of epochs
        imgsz=640,                # Image size
        batch=8,                  # Reduced batch size for memory saving
        name='cavity detection',  # Save name for the run
        device='0',               # Use GPU (set to '0' for first GPU, 'cpu' for CPU)
        project=r'cavity detection',  # Set the directory to save results on E drive
        exist_ok=True,            # Overwrite if the directory exists
        save_period=10,           # Save model every 10 epochs for checkpoints
        cache=True,               # Cache images to improve training speed
        workers=2,                # Reduced number of workers to save memory
        rect=True,                # Use rectangular training images (can help in some cases)
        resume=False,             # Resume training if interrupted
        amp=True,                 # Use mixed precision training (FP16)
        save_json=True,           # Save results in JSON format
        plots=True,               # Plot training results
        augment=True,             # Use augmentation for better results
        mixup=0.1,                # Apply mixup augmentation
        flipud=0.1,               # Flip images vertically
        fliplr=0.5,               # Flip images horizontally
        conf=0.01,                # Confidence threshold for detection
        iou=0.5,                  # IoU threshold for NMS
        multi_scale=True,         # Use multi-scale training for robustness
    )

    # Save the trained model
    model.save(r'cavity detection.pt')  # Save the model to E drive

    # After training, validate and save results
    model.val(save_json=True)  # Perform validation and save results in JSON format

    # Launch TensorBoard to visualize the training process
    print("To visualize the training results, use TensorBoard by running the following command:")
    print("tensorboard --logdir F:/cavity detection/cavity.v3-release.yolov12/training_results/cavity detection")
