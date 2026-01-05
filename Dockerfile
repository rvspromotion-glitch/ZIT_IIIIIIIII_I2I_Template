FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/workspace/ComfyUI

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Install Python packages (INCLUDES sageattention!)
RUN pip install --no-cache-dir \
    xformers==0.0.23 \
    ultralytics \
    jupyterlab \
    sageattention

# Install ComfyUI (lightweight, ~100MB)
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt

WORKDIR /workspace/ComfyUI

# Install ComfyUI Manager (lightweight)
RUN cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    pip install --no-cache-dir -r ComfyUI-Manager/requirements.txt || true

# Install essential custom nodes (lightweight, code only)
RUN cd custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git

# Install requirements for custom nodes
RUN cd custom_nodes/rgthree-comfy && pip install --no-cache-dir -r requirements.txt || true
RUN cd custom_nodes/ComfyUI_essentials && pip install --no-cache-dir -r requirements.txt || true
RUN cd custom_nodes/ComfyUI-Custom-Scripts && pip install --no-cache-dir -r requirements.txt || true
RUN cd custom_nodes/ControlAltAI-Nodes && pip install --no-cache-dir -r requirements.txt || true

# Create model directories
RUN mkdir -p models/sams \
    models/ultralytics/bbox \
    models/ultralytics/segm \
    models/diffusion_models \
    models/vae \
    models/clip \
    models/loras

# Set permissions
RUN chmod -R 777 models/loras

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188 8888

CMD ["/start.sh"]
