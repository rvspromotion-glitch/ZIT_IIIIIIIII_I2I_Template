#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI (Fast Boot Mode)"
echo "==================================="

CUSTOM_NODES_REPO="https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git"
BBOX_MODELS_REPO="https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git"

Z_IMAGE_MODEL="https://www.dropbox.com/scl/fi/sq1njtjpq65xiwidi6fvx/z_image_turbo_bf16.safetensors?rlkey=or8ipkezd8rh6qwz51whgjxc5&st=eo7lv2wn&dl=1"
Z_INDEX_VAE="https://www.dropbox.com/scl/fi/g3gqm68awb0a1cu20ilof/z-index-ae.safetensors?rlkey=l0eg5y0xdmuqnr1w3k1tg6w3d&st=84so75px&dl=1"
QWEN_CLIP="https://www.dropbox.com/scl/fi/q9j0809na155sfmuvsyk0/qwen_3_4b.safetensors?rlkey=v741nmfomz66y3t0pyrihex88&st=rsa1xyvv&dl=1"

cd /workspace/ComfyUI

# Only download YOUR custom nodes (not already baked in)
if [ ! -d "custom_nodes/IIIIIIII_ZIT_V3" ]; then
    echo "Installing your custom ZIT nodes..."
    cd custom_nodes
    git clone "$CUSTOM_NODES_REPO" IIIIIIII_ZIT_V3
    
    if [ -f "IIIIIIII_ZIT_V3/requirements.txt" ]; then
        pip install -q -r IIIIIIII_ZIT_V3/requirements.txt
    fi
    
    cd ..
fi

# Download BBOX models from your repo (only if not present)
if [ ! -d "/tmp/bbox-check" ]; then
    mkdir -p /tmp/bbox-check
    echo "Checking for BBOX models..."
    cd /tmp
    git clone --depth 1 "$BBOX_MODELS_REPO" bbox-models
    
    if [ -d "bbox-models" ]; then
        cp -rn bbox-models/* /workspace/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
    fi
    
    rm -rf bbox-models
    cd /workspace/ComfyUI
fi

# Download your specific models (only if missing)
[ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ] && \
    echo "Downloading Z-Image model..." && \
    wget -q --content-disposition -O models/diffusion_models/z_image_turbo_bf16.safetensors "$Z_IMAGE_MODEL" &

[ ! -f "models/vae/z-index-ae.safetensors" ] && \
    echo "Downloading VAE..." && \
    wget -q --content-disposition -O models/vae/z-index-ae.safetensors "$Z_INDEX_VAE" &

[ ! -f "models/clip/qwen_3_4b.safetensors" ] && \
    echo "Downloading CLIP..." && \
    wget -q --content-disposition -O models/clip/qwen_3_4b.safetensors "$QWEN_CLIP" &

# Wait for background downloads
wait

echo "==================================="
echo "Starting JupyterLab..."
echo "==================================="

mkdir -p /root/.jupyter

nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/workspace/ComfyUI \
    > /workspace/jupyter.log 2>&1 &

sleep 2

echo "JupyterLab: http://YOUR_IP:8888"
echo "ComfyUI starting on port 8188..."
echo "==================================="

exec python main.py --listen 0.0.0.0 --port 8188
