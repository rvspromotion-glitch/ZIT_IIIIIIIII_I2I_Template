#!/usr/bin/env bash
set -e

WORK_DIR="/workspace/ComfyUI"
BAKED_APP="/opt/ComfyUI"

echo "--- Setting up Volume Paths ---"
mkdir -p "$WORK_DIR/models/diffusion_models" "$WORK_DIR/models/vae" "$WORK_DIR/models/clip" "$WORK_DIR/custom_nodes"

# Download function for the big models
smart_download() {
    if [ ! -f "$2" ]; then
        echo "Downloading to Volume: $2"
        aria2c -c -x 16 -s 16 -d "$(dirname "$2")" -o "$(basename "$2")" "$1"
    fi
}

echo "--- Downloading Heavy Models to Volume ---"
# These stay on your RunPod volume across restarts
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" "$WORK_DIR/models/diffusion_models/z_image_turbo_bf16.safetensors" &
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" "$WORK_DIR/models/vae/ae.safetensors" &
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" "$WORK_DIR/models/clip/qwen_3_4b.safetensors" &
wait

echo "--- Symlinking Code & Nodes ---"
# Link the 'Brains' from /opt into your workspace
for node in "$BAKED_APP/custom_nodes"/*; do
    ln -sfn "$node" "$WORK_DIR/custom_nodes/$(basename "$node")"
done
ln -sfn "$BAKED_APP/main.py" "$WORK_DIR/main.py"

# Start JupyterLab
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --ServerApp.token='' --ServerApp.password='' --ServerApp.allow_origin='*' --ServerApp.root_dir="/workspace" > /workspace/jupyter.log 2>&1 &

echo "--- Launching ComfyUI ---"
cd "$WORK_DIR"
exec python3 main.py --listen 0.0.0.0 --port 8188
