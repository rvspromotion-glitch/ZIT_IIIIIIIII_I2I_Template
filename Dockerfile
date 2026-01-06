FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1

# 1. System Deps
RUN apt-get update && apt-get install -y git wget curl aria2 libgl1 libglib2.0-0 ffmpeg && rm -rf /var/lib/apt/lists/*

# 2. Critical Python Deps (Including Mediapipe)
RUN pip install "numpy<2" "protobuf<5" "transformers>=4.44.2" "safetensors" \
    "ultralytics" "onnxruntime-gpu" "mediapipe==0.10.14" "jupyterlab"

# 3. ComfyUI Core
WORKDIR /opt/ComfyUI
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git . && \
    pip install -r requirements.txt

# 4. Your Node List
WORKDIR /opt/ComfyUI/custom_nodes
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone --depth 1 https://github.com/chrisgoringe/cg-use-everywhere.git && \
    git clone --depth 1 https://github.com/ClownsharkBatwing/RES4LYF.git && \
    git clone --depth 1 https://github.com/djbielejeski/a-person-mask-generator.git && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone --depth 1 https://github.com/gseth/ControlAltAI-Nodes.git && \
    git clone --depth 1 https://github.com/fairy-root/ComfyUI-Show-Text.git

# 5. Install Node Requirements & Clean up to save space
RUN find . -maxdepth 2 -name "requirements.txt" -exec pip install -r {} \; && \
    rm -rf /root/.cache/pip

COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /workspace
CMD ["/start.sh"]
