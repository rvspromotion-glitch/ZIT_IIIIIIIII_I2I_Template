FROM yanwk/comfyui-boot:cu128

# Install additional Python packages
RUN pip install --no-cache-dir \
    jupyterlab \
    sageattention \
    && rm -rf /root/.cache/pip

# Download models at build time to save startup time
WORKDIR /root/ComfyUI

# Create model directories
RUN mkdir -p models/sams \
    models/ultralytics/bbox \
    models/ultralytics/segm \
    models/loras \
    models/embeddings

# Download SAM models
RUN cd models/sams && \
    wget -q https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth && \
    wget -q https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth

# Download YOLO models
RUN cd models/ultralytics/bbox && \
    wget -q -O yolov8n.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt && \
    wget -q -O yolov8n-pose.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-pose.pt && \
    wget -q -O yolov8m.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt && \
    wget -q -O hand_yolov8n.pt https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt && \
    (wget -q -O yolov8n-face.pt https://github.com/derronqi/yolov8-face/releases/download/v0.0.0/yolov8n-face.pt || true)

RUN cd models/ultralytics/segm && \
    wget -q -O yolov8n-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n-seg.pt && \
    wget -q -O yolov8m-seg.pt https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m-seg.pt

# Install essential custom nodes
RUN cd custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git && \
    for node in */; do \
        if [ -f "$node/requirements.txt" ]; then \
            pip install --no-cache-dir -r "$node/requirements.txt" || true; \
        fi \
    done && \
    rm -rf /root/.cache/pip

# Set permissions
RUN chmod -R 777 models/loras models/embeddings

# Copy startup script
COPY start-custom.sh /start-custom.sh
RUN chmod +x /start-custom.sh

WORKDIR /root/ComfyUI

CMD ["/start-custom.sh"]
