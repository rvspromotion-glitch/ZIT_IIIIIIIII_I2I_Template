#!/usr/bin/env bash
set -euo pipefail

echo "==================================="
echo "Starting ComfyUI Setup"
echo "==================================="

COMFY_DIR="${COMFYUI_PATH:-/workspace/ComfyUI}"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
MODELS_DIR="${COMFY_DIR}/models"

# Optional baked fallback (if /workspace is a mounted empty volume)
BAKED_DIR="${COMFYUI_BAKED:-/opt/ComfyUI}"

mkdir -p "$(dirname "$COMFY_DIR")"

# If ComfyUI is missing but baked exists, restore it (RunPod volume mount scenario)
if [ ! -f "${COMFY_DIR}/main.py" ] && [ -f "${BAKED_DIR}/main.py" ]; then
  echo "[setup] Restoring ComfyUI from ${BAKED_DIR} -> ${COMFY_DIR} (workspace mount detected)"
  rm -rf "${COMFY_DIR}"
  cp -a "${BAKED_DIR}" "${COMFY_DIR}"
fi

# Sanity
if [ ! -f "${COMFY_DIR}/main.py" ]; then
  echo "[fatal] ComfyUI not found at ${COMFY_DIR}. Check Dockerfile build or RunPod volume mount."
  exit 1
fi

mkdir -p "${CUSTOM_NODES}" "${MODELS_DIR}"

# -----------------------------
# Speed: persistent pip cache + less noise
# -----------------------------
export PIP_CACHE_DIR=/workspace/.cache/pip
export PIP_DISABLE_PIP_VERSION_CHECK=1
mkdir -p "$PIP_CACHE_DIR"

# -----------------------------
# Hard constraints (prevents numpy 2.x + transformers drift)
# This is what fixes the "worked until symlinks" issue.
# -----------------------------
CONSTRAINTS_FILE="/workspace/.pip-constraints.txt"
cat > "$CONSTRAINTS_FILE" <<'EOF'
numpy<2
protobuf<5
transformers==4.39.3
tokenizers==0.15.2
safetensors
mediapipe==0.10.14
EOF

# Force pip everywhere (including any prestartup scripts that call pip) to obey constraints
export PIP_CONSTRAINT="$CONSTRAINTS_FILE"

echo "[pip] Enforcing constraints:"
cat "$CONSTRAINTS_FILE"

# Make sure core stack is aligned right now (fast if already satisfied)
pip install -q --upgrade --prefer-binary \
  -c "$CONSTRAINTS_FILE" \
  "numpy<2" \
  "protobuf<5" \
  "transformers==4.39.3" \
  "tokenizers==0.15.2" \
  "safetensors" \
  "mediapipe==0.10.14" || true

echo "[debug] Versions:"
python3 - <<'PY'
import sys
print("python:", sys.version)
import torch
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
try:
    import numpy
    print("numpy:", numpy.__version__)
except Exception as e:
    print("numpy import failed:", e)
try:
    import transformers
    print("transformers:", transformers.__version__)
except Exception as e:
    print("transformers import failed:", e)
PY

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

  if command -v aria2c >/dev/null 2>&1; then
    aria2c -c -x 16 -s 16 -k 1M \
      --allow-overwrite=true \
      --file-allocation=none \
      -d "$(dirname "$out")" -o "$(basename "$out")" \
      "$url"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 8 --retry-delay 2 -C - -o "$out" "$url"
  else
    wget -c -O "$out" "$url"
  fi
}

# Install requirements but never allow torch stack to be changed.
# Also keep constraints active, and prefer wheels for speed.
safe_pip_install_req() {
  local req="$1"
  [ -f "$req" ] || return 0

  # Filter torch stack lines (never touch base torch)
  if grep -qiE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req"; then
    echo "    [pip] filtering torch lines in $req"
    local tmpreq
    tmpreq="$(mktemp)"
    grep -viE '^(torch|torchvision|torchaudio)([<=> ].*)?$' "$req" > "$tmpreq" || true
    pip install -q --prefer-binary -c "$CONSTRAINTS_FILE" -r "$tmpreq" || true
    rm -f "$tmpreq"
  else
    pip install -q --prefer-binary -c "$CONSTRAINTS_FILE" -r "$req" || true
  fi
}

# -----------------------------
# Model directories
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
# Model downloads (parallel batches)
# -----------------------------
echo "[models] Downloading required models (parallel batches)..."

# Batch 1
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "${MODELS_DIR}/sams/sam_vit_b_01ec64.pth" &
download "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth" \
  "${MODELS_DIR}/sams/sam_vit_l_0b3195.pth" &

download "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt" \
  "${MODELS_DIR}/ultralytics/bbox/face_yolov8m.pt" &
download "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
  "${MODELS_DIR}/ultralytics/segm/person_yolov8m-seg.pt" &
wait

# Batch 2
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

# Batch 3 (z-image turbo)
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors" &
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "${MODELS_DIR}/vae/ae.safetensors" &
download "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "${MODELS_DIR}/clip/qwen_3_4b.safetensors" &
wait

echo "[models] Downloads completed."

# -----------------------------
# Extra BBOX models repo (cache on volume, copy .pt once)
# -----------------------------
BBOX_DIR="${MODELS_DIR}/ultralytics/bbox"
REPO_CACHE="/workspace/_repos"
ULTRA_REPO_DIR="${REPO_CACHE}/IIIIIIIII_ZIT_V3_Ultralytics"
mkdir -p "$REPO_CACHE"

UPDATE_MODELS="${UPDATE_MODELS:-0}"

if [ ! -d "${ULTRA_REPO_DIR}/.git" ]; then
  echo "[bbox] cloning ultralytics model repo (one-time)..."
  rm -rf "${ULTRA_REPO_DIR}"
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --progress \
    "https://github.com/rvspromotion-glitch/IIIIIIIII_ZIT_V3_Ultralytics.git" \
    "${ULTRA_REPO_DIR}"
elif [ "$UPDATE_MODELS" = "1" ]; then
  echo "[bbox] updating ultralytics model repo..."
  git -C "${ULTRA_REPO_DIR}" pull --rebase || true
else
  echo "[bbox] using cached ultralytics model repo (no pull)"
fi

# Copy only if not already done (fast boots)
if [ ! -f "/workspace/.bbox-models-copied" ] || [ "$UPDATE_MODELS" = "1" ]; then
  echo "[bbox] syncing .pt files into ${BBOX_DIR}..."
  find "${ULTRA_REPO_DIR}" -type f -name "*.pt" -exec cp -f {} "${BBOX_DIR}/" \; || true
  touch /workspace/.bbox-models-copied
fi

# -----------------------------
# Node pack via SYMLINKS (FAST)
# -----------------------------
ZIT_REPO_DIR="${REPO_CACHE}/IIIIIIII_ZIT_V3"
UPDATE_NODES="${UPDATE_NODES:-0}"

if [ ! -d "${ZIT_REPO_DIR}/.git" ]; then
  echo "[nodes] cloning node pack into cache (one-time)..."
  rm -rf "${ZIT_REPO_DIR}"
  # shallow + shallow submodules = much faster
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --shallow-submodules --recurse-submodules --progress \
    "https://github.com/rvspromotion-glitch/IIIIIIII_ZIT_V3.git" \
    "${ZIT_REPO_DIR}"
  git -C "${ZIT_REPO_DIR}" submodule update --init --recursive --depth 1 || true
elif [ "$UPDATE_NODES" = "1" ]; then
  echo "[nodes] updating cached node pack..."
  git -C "${ZIT_REPO_DIR}" pull --rebase || true
  git -C "${ZIT_REPO_DIR}" submodule update --init --recursive || true
else
  echo "[nodes] using cached node pack (no pull)"
fi

echo "[nodes] creating symlinks in custom_nodes..."
for dir in "${ZIT_REPO_DIR}"/*; do
  [ -d "$dir" ] || continue
  node_name="$(basename "$dir")"

  case "$node_name" in
    .git|.github|__pycache__)
      continue
      ;;
  esac

  # If you ever need to skip a problematic node, add it here:
  # case "$node_name" in ComfyUI-RunComfy-Helper) continue ;; esac

  ln -sfn "$dir" "${CUSTOM_NODES}/${node_name}"
done

# -----------------------------
# Install node requirements ONCE (fast after first boot due to pip cache)
# You can disable runtime installs by setting INSTALL_NODE_REQS=0
# -----------------------------
INSTALL_NODE_REQS="${INSTALL_NODE_REQS:-1}"
if [ "$INSTALL_NODE_REQS" = "1" ]; then
  if [ ! -f "/workspace/.node-reqs-installed" ] || [ "$UPDATE_NODES" = "1" ]; then
    echo "[pip] Installing node requirements (once, constrained)..."
    for dir in "${ZIT_REPO_DIR}"/*; do
      [ -d "$dir" ] || continue
      req="${dir}/requirements.txt"
      if [ -f "$req" ]; then
        echo "  - [pip] $(basename "$dir")/requirements.txt"
        safe_pip_install_req "$req"
      fi
    done
    touch /workspace/.node-reqs-installed
  else
    echo "[pip] Node requirements already installed (skip)"
  fi
fi

# Final safety: ensure numpy stayed <2
pip install -q --upgrade --prefer-binary -c "$CONSTRAINTS_FILE" "numpy<2" || true

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
