# iDENTify

**iDENTify** is a dental image classification app powered by computer vision and deep learning. Built to assist in preliminary dental diagnostics, the system uses trained models to classify intraoral images and highlight potential dental conditions.

This project emphasizes the use of advanced computer vision techniques tailored for medical imagery — focusing on performance, accuracy, and ease of deployment in clinical and research settings.

---

## 🧠 Core Computer Vision Components

- **Image Classification**  
  Built using **TensorFlow** and **Keras**, Identify uses CNN-based architectures fine-tuned on curated dental datasets to classify teeth, identify common issues (e.g., caries, plaque), and segment specific regions.

- **Preprocessing Pipelines**  
  Utilizes **OpenCV** and **scikit-image** to normalize lighting, isolate regions of interest, and enhance clinical image clarity.

- **Model Optimization**  
  Exported models are converted with **ONNX** and optionally accelerated using **TensorRT** for deployment on platforms like **Jetson Nano** and other embedded devices.

- **Visualization Tools**  
  Real-time result rendering with overlays using OpenCV and Matplotlib to support intuitive review.

---

## Tech Stack

| Purpose               | Tools / Libraries                      |
|-----------------------|-----------------------------------------|
| Deep Learning         | TensorFlow, Keras, ONNX, PyTorch (optional) |
| Image Processing      | OpenCV, scikit-image                   |
| Deployment (Edge)     | Jetson Nano, TensorRT, Flask (optional API) |
| Annotation / Datasets | CVAT, LabelImg                         |

---

## Directory Structure
identify/
├── models/             # Trained TensorFlow/ONNX models
├── data/               # Sample dental image dataset
├── src/
│   ├── preprocess/     # Image filtering, ROI extraction
│   ├── classify/       # Model loading and prediction
│   └── visualize/      # Overlay outputs, UI hooks
├── app.py              # Optional Flask web API
└── README.md

---

##  Quickstart

```bash
git clone https://github.com/yourusername/identify.git
cd identify
pip install -r requirements.txt
python src/classify/classify_image.py --image path/to/image.jpg
