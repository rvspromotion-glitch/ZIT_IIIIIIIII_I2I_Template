FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.10 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

WORKDIR /workspace

# Install PyTorch and essential packages
RUN pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    && pip install --no-cache-dir \
    xformers \
    ultralytics \
    jupyterlab \
    sageattention

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt

WORKDIR /workspace/ComfyUI

# Create directories
RUN mkdir -p models/sams \
    models/ultralytics/bbox \
    models/ultralytics/segm \
    models/diffusion_models \
    models/vae \
    models/clip \
    models/loras

# Download SAM models
RUN cd models/sams && \
    wget -q https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth && \
    wget -q https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth

# Download YOLO models
RUN cd models/ultralytics/bbox && \
    wget -q -O yolov8n.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt && \
    wget -q -O yolov8n-pose.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt && \
    wget -q -O yolov8m.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt && \
    wget -q -O hand_yolov8n.pt https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt

RUN cd models/ultralytics/segm && \
    wget -q -O yolov8n-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt && \
    wget -q -O yolov8m-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt

# Install ComfyUI Manager
RUN cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip install --no-cache-dir -r requirements.txt || true

# Install essential custom nodes
RUN cd custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git && \
    for dir in rgthree-comfy ComfyUI_essentials ComfyUI-Custom-Scripts ControlAltAI-Nodes; do \
        if [ -f "$dir/requirements.txt" ]; then \
            pip install --no-cache-dir -r "$dir/requirements.txt" || true; \
        fi \
    done

# Cleanup
RUN rm -rf /root/.cache/pip /tmp/* /var/tmp/*

# Set permissions
RUN chmod -R 777 models/loras

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188 8888

CMD ["/start.sh"]
