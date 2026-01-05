#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

# Check if ComfyUI exists, if not install it
if [ ! -d "/workspace/ComfyUI" ] || [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "ComfyUI not found! Installing..."
    cd /workspace
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    pip install --no-cache-dir -r requirements.txt
    
    # Install ComfyUI Manager
    cd custom_nodes
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    pip install --no-cache-dir -r ComfyUI-Manager/requirements.txt || true
    
    # Install essential custom nodes
    git clone https://github.com/rgthree/rgthree-comfy.git && \
        cd rgthree-comfy && pip install --no-cache-dir -r requirements.txt || true && cd ..
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
        cd ComfyUI_essentials && pip install --no-cache-dir -r requirements.txt || true && cd ..
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
        cd ComfyUI-Custom-Scripts && pip install --no-cache-dir -r requirements.txt || true && cd ..
    git clone https://github.com/gseth/ControlAltAI-Nodes.git && \
        cd ControlAltAI-Nodes && pip install --no-cache-dir -r requirements.txt || true && cd ..
    
    cd /workspace/ComfyUI
fi

cd /workspace/ComfyUI

# Ensure all directories exist
mkdir -p models/sams models/ultralytics/bbox models/ultralytics/segm \
         models/diffusion_models models/vae models/clip models/loras custom_nodes

# ===== DOWNLOAD SAM MODELS (if not exists) =====
echo "Checking SAM models..."
[ ! -f "models/sams/sam_vit_b_01ec64.pth" ] && \
    wget -q --show-progress -O models/sams/sam_vit_b_01ec64.pth \
    https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth &

[ ! -f "models/sams/sam_vit_l_0b3195.pth" ] && \
    wget -q --show-progress -O models/sams/sam_vit_l_0b3195.pth \
    https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth &

# ===== DOWNLOAD YOLO BBOX MODELS (if not exists) =====
echo "Checking YOLO bbox models..."
[ ! -f "models/ultralytics/bbox/yolov8n.pt" ] && \
    wget -q --show-progress -O models/ultralytics/bbox/yolov8n.pt \
    https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt &

[ ! -f "models/ultralytics/bbox/yolov8n-pose.pt" ] && \
    wget -q --show-progress -O models/ultralytics/bbox/yolov8n-pose.pt \
    https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt &

[ ! -f "models/ultralytics/bbox/yolov8m.pt" ] && \
    wget -q --show-progress -O models/ultralytics/bbox/yolov8m.pt \
    https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt &

[ ! -f "models/ultralytics/bbox/hand_yolov8n.pt" ] && \
    wget -q --show-progress -O models/ultralytics/bbox/hand_yolov8n.pt \
    https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt &

# ===== DOWNLOAD YOLO SEGMENTATION MODELS (if not exists) =====
echo "Checking YOLO segmentation models..."
[ ! -f "models/ultralytics/segm/yolov8n-seg.pt" ] && \
    wget -q --show-progress -O models/ultralytics/segm/yolov8n-seg.pt \
    https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt &

[ ! -f "models/ultralytics/segm/yolov8m-seg.pt" ] && \
    wget -q --show-progress -O models/ultralytics/segm/yolov8m-seg.pt \
    https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt &

# ===== INSTALL YOUR CUSTOM NODES FROM GITHUB =====
if [ ! -f "/workspace/.custom-nodes-installed" ]; then
    echo "Installing custom nodes from GitHub..."
    (
        cd /tmp
        git clone --depth 1 https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git zit_custom_nodes
        cd zit_custom_nodes
        
        for dir in */; do
            if [ -d "$dir" ]; then
                node_name=$(basename "$dir")
                echo "Installing: $node_name"
                cp -r "$dir" "/workspace/ComfyUI/custom_nodes/$node_name"
                
                if [ -f "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" ]; then
                    pip install -q -r "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" || true
                fi
            fi
        done
        
        rm -rf /tmp/zit_custom_nodes
    ) &
    touch /workspace/.custom-nodes-installed
fi

# ===== DOWNLOAD YOUR BBOX MODELS FROM GITHUB =====
if [ ! -f "/workspace/.bbox-models-installed" ]; then
    echo "Downloading BBOX models from GitHub..."
    (
        cd /tmp
        git clone --depth 1 https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git bbox-models
        [ -d "bbox-models" ] && cp -r bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
        rm -rf bbox-models
    ) &
    touch /workspace/.bbox-models-installed
fi

# Download main models in background
echo "Checking main models..."
[ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ] && \
    wget -q --show-progress -O models/diffusion_models/z_image_turbo_bf16.safetensors \
    https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors &

[ ! -f "models/vae/ae.safetensors" ] && \
    wget -q --show-progress -O models/vae/ae.safetensors \
    https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors &

[ ! -f "models/clip/qwen_3_4b.safetensors" ] && \
    wget -q --show-progress -O models/clip/qwen_3_4b.safetensors \
    https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors &

# ===== START JUPYTERLAB =====
echo "Starting JupyterLab..."
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/workspace/ComfyUI \
    >/workspace/jupyter.log 2>&1 &

echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo "ComfyUI: http://YOUR_POD:8188"
echo "Jupyter:  http://YOUR_POD:8888"
echo "==================================="
echo "Starting ComfyUI..."
echo "Models downloading in background..."
echo "==================================="

# Start ComfyUI immediately (models will download in background)
cd /workspace/ComfyUI
exec python main.py --listen 0.0.0.0 --port 8188
