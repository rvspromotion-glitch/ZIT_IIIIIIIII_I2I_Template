#!/usr/bin/env bash
set -euo pipefail

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

COMFY_DIR="${COMFYUI_PATH:-/workspace/ComfyUI}"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
MODELS_DIR="${COMFY_DIR}/models"

# Sanity: ComfyUI must already exist in the image
if [ ! -f "${COMFY_DIR}/main.py" ]; then
  echo "[fatal] ComfyUI not found at ${COMFY_DIR}. Check Dockerfile build."
  exit 1
fi

mkdir -p "${CUSTOM_NODES}" "${MODELS_DIR}"

# -----------------------------
# Helpers
# -----------------------------
download() {
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"
  if [ -f "$out" ] && [ -s "$out" ]; then
    echo "[models] exists: $out"
    return 0
  fi
  echo "[models] downloading: $out"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 8 --retry-delay 2 -C - -o "$out" "$url"
  else
    wget -c -O "$out" "$url"
  fi
}

safe_pip_install_req() {
  local req="$1"
  # filter torch lines (keep base torch stable)
  if grep -qiE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req"; then
    tmpreq="$(mktemp)"
    grep -viE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req" > "$tmpreq" || true
    pip install --no-cache-dir -r "$tmpreq" -q || true
    rm -f "$tmpreq"
  else
    pip install --no-cache-dir -r "$req" -q || true
  fi
}

# -----------------------------
# Pin transformers to match torch 2.1.1
# This prevents: torch.utils._pytree.register_pytree_node crash
# -----------------------------
echo "[pip] Pinning HF stack compatible with torch 2.1.1..."
pip install --no-cache-dir -q \
  "transformers==4.39.3" \
  "tokenizers==0.15.2" \
  "protobuf<5" \
  "safetensors" || true

echo "[debug] Versions:"
python3 - <<'PY'
import sys
print("python:", sys.version)
import torch
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
try:
    import transformers
    print("transformers:", transformers.__version__)
except Exception as e:
    print("transformers import failed:", e)
try:
    import numpy
    print("numpy:", numpy.__version__)
except Exception as e:
    print("numpy import failed:", e)
PY

# -----------------------------
# Models (SAM / YOLO / z-image)
# -----------------------------
mkdir -p \
  "${MODELS_DIR}/sams" \
  "${MODELS_DIR}/ultralytics/bbox" \
  "${MODELS_DIR}/ultralytics/segm" \
  "${MODELS_DIR}/diffusion_models" \
  "${MODELS_DIR}/vae" \
  "${MODELS_DIR}/clip" \
  "${MODELS_DIR}/loras"

chmod -R 777 "${MODELS_DIR}/loras" || true

echo "[models] Downloading required models..."

download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "${MODELS_DIR}/sams/sam_vit_b_01ec64.pth"
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth" \
  "${MODELS_DIR}/sams/sam_vit_l_0b3195.pth"

download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8n.pt"
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8n-pose.pt"
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8m.pt"
download "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt" \
  "${MODELS_DIR}/ultralytics/bbox/hand_yolov8n.pt"

download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/yolov8n-seg.pt"
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/yolov8m-seg.pt"

download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors"
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "${MODELS_DIR}/vae/ae.safetensors"
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "${MODELS_DIR}/clip/qwen_3_4b.safetensors"

echo "[models] Downloads completed."

# -----------------------------
# Install your node pack (only once per pod disk)
# -----------------------------
if [ ! -f "/workspace/.custom-nodes-installed" ]; then
  echo "[nodes] Installing custom nodes from your repo..."
  tmp="/tmp/zit_custom_nodes"
  rm -rf "$tmp"
  git clone --recurse-submodules --progress "https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git" "$tmp"
  git -C "$tmp" submodule update --init --recursive || true

  for dir in "$tmp"/*; do
    [ -d "$dir" ] || continue
    node_name="$(basename "$dir")"
    if [ "$node_name" = ".git" ] || [ "$node_name" = ".github" ]; then
      continue
    fi

    echo "  - installing: $node_name"
    rm -rf "${CUSTOM_NODES}/${node_name}"
    mkdir -p "${CUSTOM_NODES}/${node_name}"
    (cd "$dir" && tar --exclude=.git --exclude=.gitmodules --exclude=.github -cf - .) | \
      (cd "${CUSTOM_NODES}/${node_name}" && tar -xf -)

    if [ -f "${CUSTOM_NODES}/${node_name}/requirements.txt" ]; then
      echo "    [pip] ${node_name}/requirements.txt"
      safe_pip_install_req "${CUSTOM_NODES}/${node_name}/requirements.txt"
    fi
  done

  rm -rf "$tmp"
  touch /workspace/.custom-nodes-installed
fi

# Remove junk folders ComfyUI tries to import
rm -rf "${CUSTOM_NODES}/.git" "${CUSTOM_NODES}/.gitmodules" "${CUSTOM_NODES}/.ipynb_checkpoints" 2>/dev/null || true

# -----------------------------
# Start JupyterLab
# -----------------------------
echo "[jupyter] Starting JupyterLab..."
jupyter lab \
  --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
  --ServerApp.token='' --ServerApp.password='' \
  --ServerApp.allow_origin='*' \
  --ServerApp.root_dir="${COMFY_DIR}" \
  >/workspace/jupyter.log 2>&1 &

echo "==================================="
echo "Launching ComfyUI"
echo "==================================="

cd "${COMFY_DIR}"
exec python3 main.py --listen 0.0.0.0 --port 8188
