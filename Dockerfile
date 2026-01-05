FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/workspace/ComfyUI

RUN apt-get update && apt-get install -y \
    git wget curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# ---- CRITICAL: keep numpy < 2 to avoid compiled-extension issues ----
RUN pip install --no-cache-dir "numpy<2"

# ---- CRITICAL: upgrade torch stack (CUDA 12.1 wheels) ----
# This resolves: torch.utils._pytree.register_pytree_node missing
RUN pip install --no-cache-dir --upgrade \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Reinstall xformers AFTER torch upgrade (do NOT pin 0.0.23 anymore)
RUN pip install --no-cache-dir --upgrade xformers

# Your other deps (keep these AFTER torch/xformers)
RUN pip install --no-cache-dir \
    ultralytics \
    jupyterlab \
    sageattention \
    sentencepiece \
    protobuf

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt

WORKDIR /workspace/ComfyUI

# ComfyUI Manager
RUN cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    pip install --no-cache-dir -r ComfyUI-Manager/requirements.txt || true

# Essential custom nodes
RUN cd custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git

# Node requirements (best-effort)
RUN cd custom_nodes/rgthree-comfy && pip install --no-cache-dir -r requirements.txt || true
RUN cd custom_nodes/ComfyUI_essentials && pip install --no-cache-dir -r requirements.txt || true
RUN cd custom_nodes/ComfyUI-Custom-Scripts && pip install --no-cache-dir -r requirements.txt || true
RUN cd custom_nodes/ControlAltAI-Nodes && pip install --no-cache-dir -r requirements.txt || true

# Model directories
RUN mkdir -p models/sams \
    models/ultralytics/bbox \
    models/ultralytics/segm \
    models/diffusion_models \
    models/vae \
    models/clip \
    models/loras

RUN chmod -R 777 models/loras

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188 8888
CMD ["/start.sh"]
