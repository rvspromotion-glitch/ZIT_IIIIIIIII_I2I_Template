#!/usr/bin/env bash
set -euo pipefail

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

COMFY_DIR="${COMFYUI_PATH:-/workspace/ComfyUI}"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
MODELS_DIR="${COMFY_DIR}/models"

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

# Install requirements but DO NOT allow it to upgrade torch/torchvision/torchaudio
safe_pip_install_req() {
  local req="$1"
  # If req contains torch lines, filter them out to avoid breaking the base torch
  if grep -qiE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req"; then
    echo "    [pip] filtering torch lines in $req"
    tmpreq="$(mktemp)"
    grep -viE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req" > "$tmpreq" || true
    pip install --no-cache-dir -r "$tmpreq" -q || true
    rm -f "$tmpreq"
  else
    pip install --no-cache-dir -r "$req" -q || true
  fi
}

# -----------------------------
# Keep env sane
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
  echo "[comfy] ComfyUI not found, cloning..."
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
  "${MODELS_DIR}/loras"

chmod -R 777 "${MODELS_DIR}/loras" || true

# -----------------------------
# Download models
# -----------------------------
echo "[models] Downloading required models..."

# SAM
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "${MODELS_DIR}/sams/sam_vit_b_01ec64.pth"
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth" \
  "${MODELS_DIR}/sams/sam_vit_l_0b3195.pth"

# YOLO
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

# z-image turbo bundle (Comfy-Org)
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors"
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "${MODELS_DIR}/vae/ae.safetensors"
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "${MODELS_DIR}/clip/qwen_3_4b.safetensors"

echo "[models] Model downloads completed."

# -----------------------------
# Install nodes from your repo
# -----------------------------
if [ ! -f "/workspace/.custom-nodes-installed" ]; then
  echo "[nodes] Installing custom nodes from your repo..."
  tmp="/tmp/zit_custom_nodes"
  rm -rf "$tmp"

  # recurse submodules so it actually contains code
  git clone --recurse-submodules --progress "https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git" "$tmp"
  git -C "$tmp" submodule update --init --recursive || true

  # Copy each top-level folder into custom_nodes (skip non-dirs)
  for dir in "$tmp"/*; do
    [ -d "$dir" ] || continue
    node_name="$(basename "$dir")"

    # skip git metadata if present
    if [ "$node_name" = ".git" ] || [ "$node_name" = ".github" ]; then
      continue
    fi

    echo "  - installing: $node_name"
    rm -rf "${CUSTOM_NODES}/${node_name}"
    mkdir -p "${CUSTOM_NODES}/${node_name}"

    # copy everything except .git*
    (cd "$dir" && tar --exclude=.git --exclude=.gitmodules --exclude=.github -cf - .) | (cd "${CUSTOM_NODES}/${node_name}" && tar -xf -)

    # install per-node requirements safely (no torch upgrades)
    if [ -f "${CUSTOM_NODES}/${node_name}/requirements.txt" ]; then
      echo "    [pip] ${node_name}/requirements.txt"
      safe_pip_install_req "${CUSTOM_NODES}/${node_name}/requirements.txt"
    fi
  done

  rm -rf "$tmp"
  touch /workspace/.custom-nodes-installed
fi

# -----------------------------
# Custom git #2: bbox models repo
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
echo "[jupyter] Starting JupyterLab..."
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
# Start ComfyUI
# -----------------------------
cd "${COMFY_DIR}"
if ! python3 main.py --listen 0.0.0.0 --port 8188; then
  echo "====================================="
  echo "ERROR: ComfyUI crashed!"
  echo "====================================="
  echo "Keeping container alive for debugging..."
  tail -f /dev/null
fi
