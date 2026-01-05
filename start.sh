#!/bin/bash
set -e

echo "==================================="
echo "Starting ComfyUI (Fast Boot)"
echo "==================================="

CUSTOM_NODES_REPO="https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git"
BBOX_MODELS_REPO="https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git"
Z_IMAGE_MODEL="https://www.dropbox.com/scl/fi/sq1njtjpq65xiwidi6fvx/z_image_turbo_bf16.safetensors?rlkey=or8ipkezd8rh6qwz51whgjxc5&st=eo7lv2wn&dl=1"
Z_INDEX_VAE="https://www.dropbox.com/scl/fi/g3gqm68awb0a1cu20ilof/z-index-ae.safetensors?rlkey=l0eg5y0xdmuqnr1w3k1tg6w3d&st=84so75px&dl=1"
QWEN_CLIP="https://www.dropbox.com/scl/fi/q9j0809na155sfmuvsyk0/qwen_3_4b.safetensors?rlkey=v741nmfomz66y3t0pyrihex88&st=rsa1xyvv&dl=1"

cd /root/ComfyUI

# Install YOUR custom nodes once
if [ ! -d "custom_nodes/IIIIIIII_ZIT_V3/.git" ]; then
    echo "Installing ZIT custom nodes..."
    cd custom_nodes
    git clone "$CUSTOM_NODES_REPO" IIIIIIII_ZIT_V3
    [ -f "IIIIIIII_ZIT_V3/requirements.txt" ] && pip install -q -r IIIIIIII_ZIT_V3/requirements.txt || true
    cd ..
fi

# Get YOUR BBOX models
if [ ! -f "/tmp/.bbox-done" ]; then
    echo "Syncing BBOX models..."
    cd /tmp
    git clone --depth 1 "$BBOX_MODELS_REPO" bbox-models 2>/dev/null || true
    [ -d "bbox-models" ] && cp -n bbox-models/* /root/ComfyUI/models/ultralytics/bbox/ 2>/dev/null || true
    rm -rf bbox-models
    touch /tmp/.bbox-done
    cd /root/ComfyUI
fi

# Download YOUR models in parallel
[ ! -f "models/diffusion_models/z_image_turbo_bf16.safetensors" ] && \
    mkdir -p models/diffusion_models && \
    wget -q -O models/diffusion_models/z_image_turbo_bf16.safetensors "$Z_IMAGE_MODEL" &

[ ! -f "models/vae/z-index-ae.safetensors" ] && \
    mkdir -p models/vae && \
    wget -q -O models/vae/z-index-ae.safetensors "$Z_INDEX_VAE" &

[ ! -f "models/clip/qwen_3_4b.safetensors" ] && \
    mkdir -p models/clip && \
    wget -q -O models/clip/qwen_3_4b.safetensors "$QWEN_CLIP" &

wait

# Start JupyterLab
echo "Starting JupyterLab on port 8888..."
nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --ServerApp.token='' --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/root/ComfyUI \
    >/tmp/jupyter.log 2>&1 &

echo "==================================="
echo "ComfyUI starting..."
echo "==================================="

# Use base image's startup if it exists, otherwise start directly
if [ -f "/scripts/entrypoint.sh" ]; then
    exec /scripts/entrypoint.sh
else
    exec python main.py --listen 0.0.0.0 --port 8188
fi
