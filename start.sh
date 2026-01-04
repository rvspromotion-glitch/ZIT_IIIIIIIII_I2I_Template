#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI Setup for RunPod"
echo "==================================="

CUSTOM_NODES_REPO="https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git"
BBOX_MODELS_REPO="https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git"

Z_IMAGE_MODEL="https://www.dropbox.com/scl/fi/sq1njtjpq65xiwidi6fvx/z_image_turbo_bf16.safetensors?rlkey=or8ipkezd8rh6qwz51whgjxc5&st=eo7lv2wn&dl=1"
Z_INDEX_VAE="https://www.dropbox.com/scl/fi/g3gqm68awb0a1cu20ilof/z-index-ae.safetensors?rlkey=l0eg5y0xdmuqnr1w3k1tg6w3d&st=84so75px&dl=1"
QWEN_CLIP="https://www.dropbox.com/scl/fi/q9j0809na155sfmuvsyk0/qwen_3_4b.safetensors?rlkey=v741nmfomz66y3t0pyrihex88&st=rsa1xyvv&dl=1"

mkdir -p /workspace/ComfyUI
cd /workspace

if [ ! -d "ComfyUI/.git" ]; then
    echo "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git
else
    echo "ComfyUI already exists, pulling latest changes..."
    cd ComfyUI
    git pull
    cd ..
fi

cd ComfyUI

echo "Installing ComfyUI requirements..."
pip install -r requirements.txt

mkdir -p custom_nodes

echo "Cloning custom nodes repository..."
if [ ! -d "/tmp/zit_custom_nodes/.git" ]; then
    cd /tmp
    git clone "$CUSTOM_NODES_REPO" zit_custom_nodes
    cd zit_custom_nodes
    
    echo "Installing custom nodes from repository..."
    for dir in */; do
        if [ -d "$dir" ]; then
            node_name=$(basename "$dir")
            echo "Processing custom node: $node_name"
            
            cp -r "$dir" "/workspace/ComfyUI/custom_nodes/$node_name"
            
            if [ -f "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" ]; then
                echo "Installing requirements for $node_name..."
                pip install -r "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt"
            fi
        fi
    done
    
    cd /workspace/ComfyUI
    rm -rf /tmp/zit_custom_nodes
fi

mkdir -p models/diffusion_models
mkdir -p models/vae
mkdir -p models/clip
mkdir -p models/ultralytics/bbox
mkdir -p models/sams
mkdir -p models/ultralytics/segm
mkdir -p models/loras
mkdir -p models/embeddings
mkdir -p models/hypernetworks

# Set permissions for upload directories
chmod -R 777 models/loras models/embeddings models/hypernetworks

echo "Downloading BBOX models from GitHub..."
if [ ! -d "/tmp/bbox-models/.git" ]; then
    cd /tmp
    git clone "$BBOX_MODELS_REPO" bbox-models
    
    if [ -d "bbox-models" ]; then
        echo "Copying BBOX models..."
        cp -r bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/
    fi
    
    rm -rf bbox-models
    cd /workspace/ComfyUI
fi

if [ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ]; then
    echo "Downloading z-image turbo bf16 model..."
    wget --content-disposition -O models/diffusion_models/z_image_turbo_bf16.safetensors "$Z_IMAGE_MODEL"
fi

if [ ! -f "models/vae/z-index-ae.safetensors" ]; then
    echo "Downloading z-index AE (VAE)..."
    wget --content-disposition -O models/vae/z-index-ae.safetensors "$Z_INDEX_VAE"
fi

if [ ! -f "models/clip/qwen_3_4b.safetensors" ]; then
    echo "Downloading Qwen CLIP..."
    wget --content-disposition -O models/clip/qwen_3_4b.safetensors "$QWEN_CLIP"
fi

echo "Downloading SAM (Segment Anything) models..."
if [ ! -f "models/sams/sam_vit_b_01ec64.pth" ]; then
    echo "Downloading SAM ViT-B..."
    wget -O models/sams/sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth
fi

if [ ! -f "models/sams/sam_vit_l_0b3195.pth" ]; then
    echo "Downloading SAM ViT-L..."
    wget -O models/sams/sam_vit_l_0b3195.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth
fi

if [ ! -f "models/sams/sam_vit_h_4b8939.pth" ]; then
    echo "Downloading SAM ViT-H (largest, most accurate)..."
    wget -O models/sams/sam_vit_h_4b8939.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth
fi

echo "Downloading YOLOv8 detection models..."
# YOLOv8 Nano - fastest, for hands/pose
if [ ! -f "models/ultralytics/bbox/yolov8n.pt" ]; then
    wget -O models/ultralytics/bbox/yolov8n.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt
fi

# YOLOv8 pose detection
if [ ! -f "models/ultralytics/bbox/yolov8n-pose.pt" ]; then
    wget -O models/ultralytics/bbox/yolov8n-pose.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt
fi

# YOLOv8 Medium - balanced
if [ ! -f "models/ultralytics/bbox/yolov8m.pt" ]; then
    wget -O models/ultralytics/bbox/yolov8m.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt
fi

echo "Downloading YOLOv8 segmentation models..."
# YOLOv8 Nano Segmentation
if [ ! -f "models/ultralytics/segm/yolov8n-seg.pt" ]; then
    wget -O models/ultralytics/segm/yolov8n-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt
fi

# YOLOv8 Medium Segmentation
if [ ! -f "models/ultralytics/segm/yolov8m-seg.pt" ]; then
    wget -O models/ultralytics/segm/yolov8m-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt
fi

# YOLOv8 Large Segmentation (more accurate)
if [ ! -f "models/ultralytics/segm/yolov8l-seg.pt" ]; then
    wget -O models/ultralytics/segm/yolov8l-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8l-seg.pt
fi

echo "Downloading specialized detection models..."
# Face detection
if [ ! -f "models/ultralytics/bbox/yolov8n-face.pt" ]; then
    wget -O models/ultralytics/bbox/yolov8n-face.pt https://github.com/akanametov/yolov8-face/releases/download/v0.0.0/yolov8n-face.pt
fi

# Hand detection (MediaPipe style)
if [ ! -f "models/ultralytics/bbox/hand_yolov8n.pt" ]; then
    wget -O models/ultralytics/bbox/hand_yolov8n.pt https://github.com/hukenovs/hagrid/releases/download/v1.0/yolov8n_hagrid_512.pt
fi

if [ ! -d "custom_nodes/ComfyUI-Manager/.git" ]; then
    echo "Installing ComfyUI Manager..."
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
    if [ -f "custom_nodes/ComfyUI-Manager/requirements.txt" ]; then
        pip install -r custom_nodes/ComfyUI-Manager/requirements.txt
    fi
fi

echo "==================================="
echo "Starting Jupyter Notebook..."
echo "==================================="

# Start Jupyter in the background
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --NotebookApp.token='' --NotebookApp.password='' \
    --notebook-dir=/workspace/ComfyUI &

echo "Jupyter started on port 8888"
echo "Access it at: http://YOUR_RUNPOD_IP:8888"
echo ""
echo "==================================="
echo "Starting ComfyUI..."
echo "==================================="

python main.py --listen 0.0.0.0 --port 8188
