FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/workspace/ComfyUI

RUN apt-get update && apt-get install -y \
    git wget curl \
    libgl1 libglib2.0-0 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Keep numpy safe (prevents many binary-extension issues)
RUN pip install --no-cache-dir "numpy<2"

# xformers must match the torch in the base image (torch 2.1.1 here)
RUN pip install --no-cache-dir --upgrade xformers==0.0.23

# Other deps (split so you can see which one fails if it ever does)
RUN pip install --no-cache-dir ultralytics
RUN pip install --no-cache-dir jupyterlab
RUN pip install --no-cache-dir sentencepiece
RUN pip install --no-cache-dir protobuf
# optional: may not have a wheel for your platform; dont fail the build
RUN pip install --no-cache-dir sageattention || true

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt

WORKDIR /workspace/ComfyUI

# Custom nodes (code only, deps handled in start.sh)
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
