#!/usr/bin/env bash
set -e

echo "==================================="
echo "Starting Stable ComfyUI Environment"
echo "==================================="

# 1. Setup Persistent Storage
# We use /workspace (RunPod's volume) for your downloads, but keep code in /opt for speed
mkdir -p /workspace/models /workspace/output /workspace/input /workspace/user_nodes

# Ensure pre-baked models are available in the UI
# This links the baked models into the active ComfyUI directory
echo "[setup] Linking models..."
cp -rn /opt/models/* /workspace/models/ || true

# 2. Start JupyterLab (Background)
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
  --ServerApp.token='' --ServerApp.password='' \
  --ServerApp.allow_origin='*' > /workspace/jupyter.log 2>&1 &

# 3. Environment Protection
# This prevents any runtime "pip install" from breaking your core dependencies
export PIP_CONSTRAINT="/opt/constraints.txt"
cat > /opt/constraints.txt <<EOF
numpy<2
transformers>=4.44.2
protobuf<5
EOF

echo "[debug] Python Version:"
python3 --version
echo "[debug] Torch Version:"
python3 -c "import torch; print(torch.__version__)"

# 4. Launch ComfyUI
# --listen 0.0.0.0 is critical for RunPod
# --extra-model-paths-config allows you to use models from the /workspace volume
cd /opt
echo "--- Launching ComfyUI ---"
exec python3 main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --input-directory /workspace/input \
    --output-directory /workspace/output
