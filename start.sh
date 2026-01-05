#!/bin/bash
set -e

echo "==================================="
echo "ComfyUI Fast Boot"
echo "==================================="

CUSTOM_NODES_REPO="https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git"
BBOX_MODELS_REPO="https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git"
Z_IMAGE_MODEL="https://www.dropbox.com/scl/fi/sq1njtjpq65xiwidi6fvx/z_image_turbo_bf16.safetensors?rlkey=or8ipkezd8rh6qwz51whgjxc5&st=eo7lv2wn&dl=1"
Z_INDEX_VAE="https://www.dropbox.com/scl/fi/g3gqm68awb0a1cu20ilof/z-index-ae.safetensors?rlkey=l0eg5y0xdmuqnr1w3k1tg6w3d&st=84so75px&dl=1"
QWEN_CLIP="https://www.dropbox.com/scl/fi/q9j0809na155sfmuvsyk0/qwen_3_4b.safetensors?rlkey=v741nmfomz66y3t0pyrihex88&st=rsa1xyvv&dl=1"

cd /workspace/ComfyUI

# Install YOUR custom nodes (once only)
if [ ! -d "custom_nodes/IIIIIIII_ZIT_V3/.git" ]; then
    echo "Installing ZIT custom nodes..."
    cd custom_nodes
    git clone "$CUSTOM_NODES_REPO" IIIIIIII_ZIT_V3
    if [ -f "IIIIIIII_ZIT_V3/requirements.txt" ]; then
        pip install -q -r IIIIIIII_ZIT_V3/requirements.txt || true
    fi
    cd ..
fi

# Download YOUR BBOX models (once only)
if [ ! -f "/tmp/.bbox-installed" ]; then
    echo "Getting BBOX models..."
    cd /tmp
    git clone --depth 1 "$BBOX_MODELS_REPO" bbox-models 2>/dev/null || true
    if [ -d "bbox-models" ]; then
        cp -n bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
    fi
    rm -rf bbox-models
    touch /tmp/.bbox-installed
    cd /workspace/ComfyUI
fi

# Download YOUR specific models in parallel (only if missing)
if [ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ]; then
    echo "Downloading Z-Image model..."
    wget -q -O models/diffusion_models/z_image_turbo_bf16.safetensors "$Z_IMAGE_MODEL" &
fi

if [ ! -f "models/vae/z-index-ae.safetensors" ]; then
    echo "Downloading VAE..."
    wget -q -O models/vae/z-index-ae.safetensors "$Z_INDEX_VAE" &
fi

if [ ! -f "models/clip/qwen_3_4b.safetensors" ]; then
    echo "Downloading CLIP..."
    wget -q -O models/clip/qwen_3_4b.safetensors "$QWEN_CLIP" &
fi

# Wait for parallel downloads
wait

echo "Starting JupyterLab on :8888..."
nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --ServerApp.token='' --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/workspace/ComfyUI \
    >/workspace/jupyter.log 2>&1 &

sleep 2

echo "==================================="
echo "Starting ComfyUI on :8188"
echo "==================================="

exec python main.py --listen 0.0.0.0 --port 8188
