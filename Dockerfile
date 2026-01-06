FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

# Bake only the "Stability" items (Pip packages + Nodes)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git wget curl aria2 libgl1 libglib2.0-0 ffmpeg && rm -rf /var/lib/apt/lists/*

# Fix dependencies once and for all in the image
RUN pip install --no-cache-dir "numpy<2" "protobuf<5" "transformers>=4.44.2" "safetensors" "ultralytics" "onnxruntime-gpu"

WORKDIR /opt/ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && pip install --no-cache-dir -r requirements.txt

# Bake your specific nodes into the image (this makes UI loading instant)
WORKDIR /opt/ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone https://github.com/chrisgoringe/cg-use-everywhere.git && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    git clone https://github.com/djbielejeski/a-person-mask-generator.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git && \
    git clone https://github.com/fairy-root/ComfyUI-Show-Text.git

# Pre-install node requirements (the 'brain' of the setup)
RUN find . -maxdepth 2 -name "requirements.txt" -exec pip install --no-cache-dir -r {} \;

COPY start.sh /start.sh
RUN chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
