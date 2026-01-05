#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

# Ensure we're in the right directory
cd /workspace/ComfyUI

# Create directories if they don't exist
mkdir -p custom_nodes
mkdir -p models/diffusion_models
mkdir -p models/vae
mkdir -p models/clip
mkdir -p models/ultralytics/bbox

# Clone YOUR custom nodes from your repo
CUSTOM_NODES_REPO="https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git"
BBOX_MODELS_REPO="https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git"

# Install custom nodes (each folder is a separate custom node)
if [ ! -d "/tmp/zit_custom_nodes_installed" ]; then
    echo "Installing your custom nodes..."
    cd /tmp
    git clone "$CUSTOM_NODES_REPO" zit_custom_nodes
    cd zit_custom_nodes
    
    # Loop through each folder and copy to custom_nodes
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
    mkdir -p /tmp/zit_custom_nodes_installed
    cd /workspace/ComfyUI
fi

# Get YOUR BBOX models
if [ ! -f "/workspace/.bbox-done" ]; then
    echo "Downloading your BBOX models..."
    cd /tmp
    git clone --depth 1 "$BBOX_MODELS_REPO" bbox-models
    if [ -d "bbox-models" ]; then
        cp -r bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
    fi
    rm -rf bbox-models
    touch /workspace/.bbox-done
    cd /workspace/ComfyUI
fi

# Download YOUR specific models
Z_IMAGE_MODEL="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors"
Z_INDEX_VAE="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"
QWEN_CLIP="https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors"

if [ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ]; then
    echo "Downloading Z-Image model..."
    wget -q --show-progress -O models/diffusion_models/z_image_turbo_bf16.safetensors "$Z_IMAGE_MODEL" &
fi

if [ ! -f "models/vae/ae.safetensors" ]; then
    echo "Downloading VAE..."
    wget -q --show-progress -O models/vae/ae.safetensors "$Z_INDEX_VAE" &
fi

if [ ! -f "models/clip/qwen_3_4b.safetensors" ]; then
    echo "Downloading CLIP..."
    wget -q --show-progress -O models/clip/qwen_3_4b.safetensors "$QWEN_CLIP" &
fi

# Wait for all downloads to complete
wait

echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo "Starting ComfyUI on port 8188..."
echo "==================================="

# Start ComfyUI
exec python main.py --listen 0.0.0.0 --port 8188
