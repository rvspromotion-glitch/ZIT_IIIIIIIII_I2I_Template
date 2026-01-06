#!/usr/bin/env bash
set -e

echo "--- Initializing ComfyUI Structure ---"

# 1. Define Paths
BAKED_APP="/opt/ComfyUI"
WORK_DIR="/workspace/ComfyUI"

# 2. Build the directory on the Volume
mkdir -p "$WORK_DIR"
mkdir -p /workspace/models /workspace/input /workspace/output

# 3. Create Symlink Tree (Makes ComfyUI visible in Workspace)
for item in "$BAKED_APP"/*; do
    base=$(basename "$item")
    case "$base" in
        models|input|output)
            # Link baked models into the volume folder (doesn't overwrite your own)
            mkdir -p "$WORK_DIR/$base"
            cp -rn "$item"/* "$WORK_DIR/$base/" 2>/dev/null || true
            ;;
        custom_nodes)
            mkdir -p "$WORK_DIR/custom_nodes"
            # Link all pre-installed nodes so they are ready
            for node in "$item"/*; do
                ln -sfn "$node" "$WORK_DIR/custom_nodes/$(basename "$node")"
            done
            ;;
        *)
            # Symlink core files
            ln -sfn "$item" "$WORK_DIR/$base"
            ;;
    esac
done

# 4. Start JupyterLab (Background)
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
  --ServerApp.token='' --ServerApp.password='' \
  --ServerApp.allow_origin='*' --ServerApp.root_dir="/workspace" > /workspace/jupyter.log 2>&1 &

# 5. Launch ComfyUI
echo "--- Launching ComfyUI ---"
cd "$WORK_DIR"
exec python3 main.py --listen 0.0.0.0 --port 8188 --input-directory /workspace/input --output-directory /workspace/output
