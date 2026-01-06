#!/usr/bin/env bash
set -e

WORK_DIR="/workspace/ComfyUI"
mkdir -p "$WORK_DIR/models/diffusion_models" "$WORK_DIR/models/vae" "$WORK_DIR/models/clip"

# Function to download ONLY if file is missing
smart_download() {
    if [ ! -f "$2" ]; then
        echo "Downloading missing model: $2"
        aria2c -c -x 16 -s 16 -d "$(dirname "$2")" -o "$(basename "$2")" "$1"
    else
        echo "Model already on volume: $(basename "$2")"
    fi
}

# Z-Image Turbo (The heavy stuff)
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" "$WORK_DIR/models/diffusion_models/z_image_turbo_bf16.safetensors" &
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" "$WORK_DIR/models/vae/ae.safetensors" &
smart_download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" "$WORK_DIR/models/clip/qwen_3_4b.safetensors" &
wait

# Create Symlinks for the Nodes (Instant)
for node in /opt/ComfyUI/custom_nodes/*; do
    ln -sfn "$node" "$WORK_DIR/custom_nodes/$(basename "$node")"
done

# Sync core files
ln -sfn /opt/ComfyUI/main.py "$WORK_DIR/main.py"

cd "$WORK_DIR"
exec python3 main.py --listen 0.0.0.0 --port 8188
