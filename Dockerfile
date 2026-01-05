FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/workspace/ComfyUI

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Install Python packages
RUN pip install --no-cache-dir \
    xformers==0.0.23 \
    ultralytics \
    jupyterlab \
    notebook \
    sageattention

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install -r requirements.txt

# Create all necessary directories
RUN mkdir -p /workspace/ComfyUI/models/diffusion_models \
    /workspace/ComfyUI/models/vae \
    /workspace/ComfyUI/models/clip \
    /workspace/ComfyUI/models/ultralytics/bbox \
    /workspace/ComfyUI/models/ultralytics/segm \
    /workspace/ComfyUI/models/sams \
    /workspace/ComfyUI/models/loras \
    /workspace/ComfyUI/models/embeddings \
    /workspace/ComfyUI/models/hypernetworks

# Install essential custom nodes (BAKED IN for fast startup)
WORKDIR /workspace/ComfyUI/custom_nodes

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip install -r requirements.txt || true

RUN git clone https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    pip install -r requirements.txt || true

RUN git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    cd ComfyUI_essentials && \
    pip install -r requirements.txt || true

RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    cd ComfyUI-Custom-Scripts && \
    pip install -r requirements.txt || true

RUN git clone https://github.com/gseth/ControlAltAI-Nodes.git && \
    cd ControlAltAI-Nodes && \
    pip install -r requirements.txt || true

# Download SAM models (BAKED IN) - Clean up layers to save space
WORKDIR /workspace/ComfyUI/models/sams
RUN wget -q -O sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth && \
    wget -q -O sam_vit_l_0b3195.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth && \
    rm -rf /tmp/* /var/tmp/*

# Download YOLOv8 detection models (BAKED IN)
WORKDIR /workspace/ComfyUI/models/ultralytics/bbox
RUN wget -q -O yolov8n.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt && \
    wget -q -O yolov8n-pose.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt && \
    wget -q -O yolov8m.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt && \
    wget -q -O yolov8n-face.pt https://github.com/derronqi/yolov8-face/releases/download/v0.0.0/yolov8n-face.pt || true && \
    wget -q -O hand_yolov8n.pt https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt && \
    rm -rf /tmp/* /var/tmp/*

# Download YOLOv8 segmentation models (BAKED IN)
WORKDIR /workspace/ComfyUI/models/ultralytics/segm
RUN wget -q -O yolov8n-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt && \
    wget -q -O yolov8m-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt && \
    rm -rf /tmp/* /var/tmp/*

# Set permissions
RUN chmod -R 777 /workspace/ComfyUI/models/loras \
    /workspace/ComfyUI/models/embeddings \
    /workspace/ComfyUI/models/hypernetworks

WORKDIR /workspace/ComfyUI

# Copy startup script for dynamic content
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188 8888

CMD ["/start.sh"]
