#!/usr/bin/env bash
set -euo pipefail

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

COMFY_DIR="${COMFYUI_PATH:-/workspace/ComfyUI}"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
MODELS_DIR="${COMFY_DIR}/models"

# Sanity: ComfyUI must already exist in the image (or in the mounted volume)
if [ ! -f "${COMFY_DIR}/main.py" ]; then
  echo "[fatal] ComfyUI not found at ${COMFY_DIR}. Check Dockerfile build or RunPod volume mount."
  exit 1
fi

mkdir -p "${CUSTOM_NODES}" "${MODELS_DIR}"

# Persistent pip cache to speed up restarts
export PIP_CACHE_DIR=/workspace/.cache/pip
export PIP_DISABLE_PIP_VERSION_CHECK=1
mkdir -p "$PIP_CACHE_DIR"

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

  # fastest: aria2c with parallel connections
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -c -x 16 -s 16 -k 1M \
      --allow-overwrite=true \
      --file-allocation=none \
      -d "$(dirname "$out")" -o "$(basename "$out")" \
      "$url"
    return 0
  fi

  # fallback: curl/wget
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 8 --retry-delay 2 -C - -o "$out" "$url"
  else
    wget -c -O "$out" "$url"
  fi
}

# Install requirements but DO NOT allow it to upgrade torch/torchvision/torchaudio.
# Also use cache (no --no-cache-dir) and prefer wheels to reduce build time.
safe_pip_install_req() {
  local req="$1"
  [ -f "$req" ] || return 0

  # Filter torch lines out of requirements to avoid breaking base torch
  if grep -qiE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req"; then
    echo "    [pip] filtering torch lines in $req"
    local tmpreq
    tmpreq="$(mktemp)"
    grep -viE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req" > "$tmpreq" || true
    pip install --prefer-binary -r "$tmpreq" -q || true
    rm -f "$tmpreq"
  else
    pip install --prefer-binary -r "$req" -q || true
  fi
}

# -----------------------------
# Pin HF stack compatible with torch 2.1.1
# -----------------------------
echo "[pip] Pinning HF stack compatible with torch 2.1.1..."
pip install -q \
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
# Models directories
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
# Model downloads (PARALLEL batches)
# -----------------------------
echo "[models] Downloading required models (parallel batches)..."

# Batch 1: SAM + extra ultralytics models
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "${MODELS_DIR}/sams/sam_vit_b_01ec64.pth" &
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth" \
  "${MODELS_DIR}/sams/sam_vit_l_0b3195.pth" &

# Extra models you asked for
download "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt" \
  "${MODELS_DIR}/ultralytics/bbox/face_yolov8m.pt" &
download "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/person_yolov8m-seg.pt" &

wait

# Batch 2: Ultralytics defaults
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8n.pt" &
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8n-pose.pt" &
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt" \
  "${MODELS_DIR}/ultralytics/bbox/yolov8m.pt" &
download "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt" \
  "${MODELS_DIR}/ultralytics/bbox/hand_yolov8n.pt" &

download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/yolov8n-seg.pt" &
download "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/yolov8m-seg.pt" &

wait

# Batch 3: z-image turbo bundle
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors" &
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "${MODELS_DIR}/vae/ae.safetensors" &
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "${MODELS_DIR}/clip/qwen_3_4b.safetensors" &

wait

echo "[models] Downloads completed."

# -----------------------------
# Extra BBOX models from your repo (copy ALL .pt into bbox)
# -----------------------------
BBOX_DIR="${MODELS_DIR}/ultralytics/bbox"
mkdir -p "${BBOX_DIR}"

if [ ! -f "/workspace/.bbox-models-installed" ]; then
  echo "[bbox] Installing extra bbox models from IIIIIIIII_ZIT_V3_Ultralytics..."

  tmp="/tmp/zit_ultra_bbox"
  rm -rf "$tmp"

  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --progress \
    "https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git" \
    "$tmp"

  find "$tmp" -type f -name "*.pt" -print -exec cp -f {} "${BBOX_DIR}/" \;

  rm -rf "$tmp"
  touch /workspace/.bbox-models-installed
else
  echo "[bbox] already installed"
fi

# -----------------------------
# Node pack via SYMLINKS (FAST)
# -----------------------------
REPO_CACHE="/workspace/_repos"
ZIT_REPO_DIR="${REPO_CACHE}/IIIIIIII_ZIT_V3"
mkdir -p "$REPO_CACHE"

# Set UPDATE_NODES=1 in RunPod env vars if you want to git pull
UPDATE_NODES="${UPDATE_NODES:-0}"

if [ ! -d "${ZIT_REPO_DIR}/.git" ]; then
  echo "[nodes] cloning node pack into cache (one-time)..."
  rm -rf "${ZIT_REPO_DIR}"
  GIT_TERMINAL_PROMPT=0 git clone --recurse-submodules --progress \
    "https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git" \
    "${ZIT_REPO_DIR}"
  git -C "${ZIT_REPO_DIR}" submodule update --init --recursive || true
elif [ "$UPDATE_NODES" = "1" ]; then
  echo "[nodes] updating cached node pack..."
  git -C "${ZIT_REPO_DIR}" pull --rebase || true
  git -C "${ZIT_REPO_DIR}" submodule update --init --recursive || true
else
  echo "[nodes] using cached node pack (no git pull)"
fi

echo "[nodes] creating symlinks in custom_nodes..."

for dir in "${ZIT_REPO_DIR}"/*; do
  [ -d "$dir" ] || continue
  node_name="$(basename "$dir")"

  # skip junk
  case "$node_name" in
    .git|.github|__pycache__)
      continue
      ;;
  esac

  echo "  - symlink: $node_name"
  ln -sfn "$dir" "${CUSTOM_NODES}/${node_name}"
done

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
