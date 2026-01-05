#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

# Fix dependencies first
echo "Ensuring compatible dependencies..."
pip install --no-cache-dir \
    "numpy<2.0.0" \
    "transformers>=4.40.0" \
    "tokenizers>=0.19.0" \
    "sentencepiece" \
    "protobuf" \
    -q || true

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

# ===== DOWNLOAD MODELS IN BACKGROUND =====
(
    echo "Downloading models in background..."
    
    # SAM models
    [ ! -f "models/sams/sam_vit_b_01ec64.pth" ] && \
        wget -q -O models/sams/sam_vit_b_01ec64.pth \
        https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth &
    
    [ ! -f "models/sams/sam_vit_l_0b3195.pth" ] && \
        wget -q -O models/sams/sam_vit_l_0b3195.pth \
        https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth &
    
    # YOLO bbox
    [ ! -f "models/ultralytics/bbox/yolov8n.pt" ] && \
        wget -q -O models/ultralytics/bbox/yolov8n.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt &
    
    [ ! -f "models/ultralytics/bbox/yolov8n-pose.pt" ] && \
        wget -q -O models/ultralytics/bbox/yolov8n-pose.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt &
    
    [ ! -f "models/ultralytics/bbox/yolov8m.pt" ] && \
        wget -q -O models/ultralytics/bbox/yolov8m.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt &
    
    [ ! -f "models/ultralytics/bbox/hand_yolov8n.pt" ] && \
        wget -q -O models/ultralytics/bbox/hand_yolov8n.pt \
        https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt &
    
    # YOLO segmentation
    [ ! -f "models/ultralytics/segm/yolov8n-seg.pt" ] && \
        wget -q -O models/ultralytics/segm/yolov8n-seg.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt &
    
    [ ! -f "models/ultralytics/segm/yolov8m-seg.pt" ] && \
        wget -q -O models/ultralytics/segm/yolov8m-seg.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt &
    
    # Main models (large, download last)
    [ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ] && \
        wget -q -O models/diffusion_models/z_image_turbo_bf16.safetensors \
        https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors &
    
    [ ! -f "models/vae/ae.safetensors" ] && \
        wget -q -O models/vae/ae.safetensors \
        https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors &
    
    [ ! -f "models/clip/qwen_3_4b.safetensors" ] && \
        wget -q -O models/clip/qwen_3_4b.safetensors \
        https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors &
    
    wait
    echo "Model downloads complete!"
) &

# ===== INSTALL CUSTOM NODES (NON-BLOCKING) =====
if [ ! -f "/workspace/.custom-nodes-installed" ]; then
    echo "Installing custom nodes from GitHub..."
    (
        cd /tmp
        if git clone --depth 1 https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git zit_custom_nodes 2>/dev/null; then
            cd zit_custom_nodes
            
            for dir in */; do
                if [ -d "$dir" ]; then
                    node_name=$(basename "$dir")
                    echo "Installing: $node_name"
                    cp -r "$dir" "/workspace/ComfyUI/custom_nodes/$node_name"
                    
                    if [ -f "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" ]; then
                        pip install -q -r "/workspace/ComfyUI/custom_nodes/$node_name/requirements.txt" 2>/dev/null || true
                    fi
                fi
            done
            
            rm -rf /tmp/zit_custom_nodes
        else
            echo "Warning: Could not clone custom nodes repo"
        fi
        touch /workspace/.custom-nodes-installed
    ) &
fi

# ===== DOWNLOAD BBOX MODELS (NON-BLOCKING) =====
if [ ! -f "/workspace/.bbox-models-installed" ]; then
    echo "Downloading BBOX models from GitHub..."
    (
        cd /tmp
        if git clone --depth 1 https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git bbox-models 2>/dev/null; then
            [ -d "bbox-models" ] && cp -r bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
            rm -rf bbox-models
        else
            echo "Warning: Could not clone bbox models repo"
        fi
        touch /workspace/.bbox-models-installed
    ) &
fi

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

# Wait a moment for any critical background tasks
sleep 2

# Start ComfyUI with detailed error logging
cd /workspace/ComfyUI

# Try to start ComfyUI - if it crashes, keep container alive to debug
if ! python main.py --listen 0.0.0.0 --port 8188; then
    echo "====================================="
    echo "ERROR: ComfyUI crashed!"
    echo "====================================="
    echo "Keeping container alive for debugging..."
    echo "Access logs with: docker logs <container_id>"
    echo "SSH into pod and check: /workspace/ComfyUI/user/comfyui.log"
    
    # Keep container running
    tail -f /dev/null
fi
