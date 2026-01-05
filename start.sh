#!/usr/bin/env bash
set -euo pipefail

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
MODELS_DIR="${COMFY_DIR}/models"

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
  # resume supported
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 5 --retry-delay 2 -C - -o "$out" "$url"
  else
    wget -c -O "$out" "$url"
  fi
}

clone_or_update() {
  local url="$1"
  local dir="$2"

  if [ -d "$dir/.git" ]; then
    echo "[git] update: $dir"
    git -C "$dir" pull --rebase || git -C "$dir" pull || true
    git -C "$dir" submodule update --init --recursive || true
  else
    echo "[git] clone: $dir"
    git clone --recurse-submodules --progress "$url" "$dir"
  fi
}

# -----------------------------
# Keep env sane (do NOT force-upgrade transformers here)
# -----------------------------
echo "[pip] Ensuring safe base versions..."
pip install --no-cache-dir "numpy<2" -q || true

echo "[debug] Versions:"
python3 - <<'PY'
import sys
print("python:", sys.version)
try:
    import torch
    print("torch:", torch.__version__)
    print("cuda:", torch.version.cuda)
except Exception as e:
    print("torch import failed:", e)
try:
    import transformers
    print("transformers:", transformers.__version__)
except Exception as e:
    print("transformers not available:", e)
PY

# -----------------------------
# Ensure ComfyUI exists
# -----------------------------
if [ ! -d "$COMFY_DIR" ] || [ ! -f "$COMFY_DIR/main.py" ]; then
  echo "ComfyUI not found! Installing..."
  cd /workspace
  git clone https://github.com/comfyanonymous/ComfyUI.git
  cd "$COMFY_DIR"
  pip install --no-cache-dir -r requirements.txt
fi

# -----------------------------
# Directories
# -----------------------------
mkdir -p \
  "${MODELS_DIR}/sams" \
  "${MODELS_DIR}/ultralytics/bbox" \
  "${MODELS_DIR}/ultralytics/segm" \
  "${MODELS_DIR}/diffusion_models" \
  "${MODELS_DIR}/vae" \
  "${MODELS_DIR}/clip" \
  "${MODELS_DIR}/loras" \
  "${CUSTOM_NODES}"

chmod -R 777 "${MODELS_DIR}/loras" || true

# -----------------------------
# Download models (HF + SAM + YOLO)
# This is deterministic + resumable.
# If you want background, you can append "&" to the whole block.
# -----------------------------
echo "[models] Downloading required models..."

# SAM models
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "${MODELS_DIR}/sams/sam_vit_b_01ec64.pth"
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth" \
  "${MODELS_DIR}/sams/sam_vit_l_0b3195.pth"

# YOLO bbox
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8n.pt"
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8n-pose.pt"
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8m.pt"
download "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt" \
  "${MODELS_DIR}/ultralytics/bbox/hand_yolov8n.pt"

# YOLO segmentation
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/yolov8n-seg.pt"
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/yolov8m-seg.pt"

# HuggingFace models you mentioned (z-image + qwen clip + ae)
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors"
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "${MODELS_DIR}/vae/ae.safetensors"
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "${MODELS_DIR}/clip/qwen_3_4b.safetensors"

echo "[models] All required model downloads completed."

# -----------------------------
# Install nodes from your repo (CUSTOM GIT #1) - FIXED: recurse submodules
# -----------------------------
if [ ! -f "/workspace/.custom-nodes-installed" ]; then
  echo "[nodes] Installing custom nodes from your repo..."
  tmp="/tmp/zit_custom_nodes"
  rm -rf "$tmp"

  # IMPORTANT FIX: recurse-submodules so folders are not empty
  git clone --recurse-submodules --progress "https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git" "$tmp"
  git -C "$tmp" submodule update --init --recursive || true

  # Copy each top-level folder into custom_nodes (exclude .git stuff)
  for dir in "$tmp"/*/; do
    [ -d "$dir" ] || continue
    node_name="$(basename "$dir")"
    echo "  - installing: $node_name"

    rm -rf "${CUSTOM_NODES}/${node_name}"
    mkdir -p "${CUSTOM_NODES}/${node_name}"

    (cd "$dir" && tar --exclude=.git --exclude=.gitmodules -cf - .) | (cd "${CUSTOM_NODES}/${node_name}" && tar -xf -)

    # install per-node requirements (best effort)
    if [ -f "${CUSTOM_NODES}/${node_name}/requirements.txt" ]; then
      echo "    pip: ${node_name}/requirements.txt"
      pip install -q -r "${CUSTOM_NODES}/${node_name}/requirements.txt" || true
    fi
  done

  rm -rf "$tmp"
  touch /workspace/.custom-nodes-installed
fi

# -----------------------------
# Download BBOX models repo (CUSTOM GIT #2)
# -----------------------------
if [ ! -f "/workspace/.bbox-models-installed" ]; then
  echo "[bbox] Downloading BBOX models repo..."
  tmp="/tmp/bbox-models"
  rm -rf "$tmp"
  git clone --depth 1 --progress "https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git" "$tmp" || true
  if [ -d "$tmp" ]; then
    cp -r "$tmp"/* "${MODELS_DIR}/ultralytics/bbox/" 2>/dev/null || true
  fi
  rm -rf "$tmp"
  touch /workspace/.bbox-models-installed
fi

# -----------------------------
# Remove junk folders that ComfyUI tries to import
# -----------------------------
rm -rf "${CUSTOM_NODES}/.git" "${CUSTOM_NODES}/.gitmodules" "${CUSTOM_NODES}/.ipynb_checkpoints" 2>/dev/null || true

# -----------------------------
# Start JupyterLab
# -----------------------------
echo "Starting JupyterLab..."
jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --ServerApp.allow_origin='*' \
  --ServerApp.root_dir="${COMFY_DIR}" \
  >/workspace/jupyter.log 2>&1 &

echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo "ComfyUI: http://YOUR_POD:8188"
echo "Jupyter: http://YOUR_POD:8888"
echo "==================================="

# -----------------------------
# Start ComfyUI (keep container alive if crash)
# -----------------------------
cd "${COMFY_DIR}"
if ! python3 main.py --listen 0.0.0.0 --port 8188; then
  echo "====================================="
  echo "ERROR: ComfyUI crashed!"
  echo "====================================="
  echo "Keeping container alive for debugging..."
  tail -f /dev/null
fi
