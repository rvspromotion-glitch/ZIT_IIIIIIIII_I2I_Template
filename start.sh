#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

cd /workspace/ComfyUI

# Ensure all directories exist
mkdir -p models/sams
mkdir -p models/ultralytics/bbox
mkdir -p models/ultralytics/segm
mkdir -p models/diffusion_models
mkdir -p models/vae
mkdir -p models/clip
mkdir -p custom_nodes

# ===== DOWNLOAD SAM MODELS (if not exists) =====
if [ ! -f "models/sams/sam_vit_b_01ec64.pth" ]; then
    echo "Downloading SAM ViT-B model..."
    wget -q --show-progress -O models/sams/sam_vit_b_01ec64.pth \
        https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth
fi

if [ ! -f "models/sams/sam_vit_l_0b3195.pth" ]; then
    echo "Downloading SAM ViT-L model..."
    wget -q --show-progress -O models/sams/sam_vit_l_0b3195.pth \
        https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth
fi

# ===== DOWNLOAD YOLO BBOX MODELS (if not exists) =====
if [ ! -f "models/ultralytics/bbox/yolov8n.pt" ]; then
    echo "Downloading YOLOv8n..."
    wget -q --show-progress -O models/ultralytics/bbox/yolov8n.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt
fi

if [ ! -f "models/ultralytics/bbox/yolov8n-pose.pt" ]; then
    echo "Downloading YOLOv8n-pose..."
    wget -q --show-progress -O models/ultralytics/bbox/yolov8n-pose.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt
fi

if [ ! -f "models/ultralytics/bbox/yolov8m.pt" ]; then
    echo "Downloading YOLOv8m..."
    wget -q --show-progress -O models/ultralytics/bbox/yolov8m.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt
fi

if [ ! -f "models/ultralytics/bbox/hand_yolov8n.pt" ]; then
    echo "Downloading Hand YOLOv8n..."
    wget -q --show-progress -O models/ultralytics/bbox/hand_yolov8n.pt \
        https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt
fi

# ===== DOWNLOAD YOLO SEGMENTATION MODELS (if not exists) =====
if [ ! -f "models/ultralytics/segm/yolov8n-seg.pt" ]; then
    echo "Downloading YOLOv8n-seg..."
    wget -q --show-progress -O models/ultralytics/segm/yolov8n-seg.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt
fi

if [ ! -f "models/ultralytics/segm/yolov8m-seg.pt" ]; then
    echo "Downloading YOLOv8m-seg..."
    wget -q --show-progress -O models/ultralytics/segm/yolov8m-seg.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt
fi

# ===== INSTALL YOUR CUSTOM NODES FROM GITHUB =====
CUSTOM_NODES_REPO="https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git"

if [ ! -f "/workspace/.custom-nodes-installed" ]; then
    echo "Installing your custom nodes from GitHub..."
    cd /tmp
    git clone "$CUSTOM_NODES_REPO" zit_custom_nodes
    cd zit_custom_nodes
    
    # Loop through each folder and install as custom node
    for dir in */; do
        if [ -d "$dir" ]; then
            node_name=$(basename "$dir")
            echo "Installing custom node: $node_name"
            cp -r "$dir" "/workspace/ComfyUI/custom_nodes/$node_name"
            
            # Install requirements if exists
            if [ -f "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" ]; then
                echo "Installing requirements for $node_name..."
                pip install -q -r "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" || true
            fi
        fi
    done
    
    rm -rf /tmp/zit_custom_nodes
    touch /workspace/.custom-nodes-installed
    cd /workspace/ComfyUI
fi

# ===== DOWNLOAD YOUR BBOX MODELS FROM GITHUB =====
BBOX_MODELS_REPO="https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git"

if [ ! -f "/workspace/.bbox-models-installed" ]; then
    echo "Downloading your BBOX models from GitHub..."
    cd /tmp
    git clone --depth 1 "$BBOX_MODELS_REPO" bbox-models
    if [ -d "bbox-models" ]; then
        cp -r bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
    fi
    rm -rf bbox-models
    touch /workspace/.bbox-models-installed
    cd /workspace/ComfyUI
fi

# Download YOUR specific models
Z_IMAGE_MODEL="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors"
Z_INDEX_VAE="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"
QWEN_CLIP="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors"

if [ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ]; then
    echo "Downloading Z-Image Turbo BF16 model (~5-10GB)..."
    wget -q --show-progress -O models/diffusion_models/z_image_turbo_bf16.safetensors "$Z_IMAGE_MODEL"
fi

if [ ! -f "models/vae/ae.safetensors" ]; then
    echo "Downloading Z-Index AE VAE (~1-2GB)..."
    wget -q --show-progress -O models/vae/ae.safetensors "$Z_INDEX_VAE"
fi

if [ ! -f "models/clip/qwen_3_4b.safetensors" ]; then
    echo "Downloading Qwen CLIP (~7-8GB)..."
    wget -q --show-progress -O models/clip/qwen_3_4b.safetensors "$QWEN_CLIP"
fi

# ===== START JUPYTERLAB =====
echo "Starting JupyterLab on port 8888..."
nohup jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/workspace/ComfyUI \
    >/workspace/jupyter.log 2>&1 &

sleep 2

echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo "ComfyUI: http://YOUR_POD:8188"
echo "Jupyter:  http://YOUR_POD:8888"
echo "==================================="
echo "Starting ComfyUI..."
echo "==================================="

# Start ComfyUI
exec python main.py --listen 0.0.0.0 --port 8188
