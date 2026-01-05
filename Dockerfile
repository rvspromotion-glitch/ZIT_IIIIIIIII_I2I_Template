FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/workspace/ComfyUI

RUN apt-get update && apt-get install -y \
    git wget curl \
    libgl1 libglib2.0-0 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Keep numpy safe
RUN pip install --no-cache-dir "numpy<2"

# Force-upgrade torch stack
RUN pip install --no-cache-dir --upgrade --force-reinstall \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Reinstall xformers AFTER torch
RUN pip install --no-cache-dir --upgrade xformers

# Other deps
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

# Custom nodes (code only, no deps here)
RUN cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git

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
