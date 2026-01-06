# Use a stable, modern Torch/CUDA base
FROM runpod/pytorch:2.4.0-py3.10-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/opt/ComfyUI
ENV PYTHONUNBUFFERED=1

# 1. Install System Dependencies
RUN apt-get update && apt-get install -y \
    git wget curl aria2 libgl1 libglib2.0-0 ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 2. Prevent Dependency Drift (The "No-Bug" Zone)
# Pre-installing these ensures no node can force an upgrade to NumPy 2.0 or break Transformers
RUN pip install --no-cache-dir "numpy<2" "protobuf<5" "transformers>=4.44.2" \
    "tokenizers>=0.19" "safetensors" "mediapipe==0.10.14" "xformers==0.0.27.post2" \
    "jupyterlab" "sentencepiece" "ultralytics" "onnxruntime-gpu"

# 3. Setup ComfyUI Core
WORKDIR /opt
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    pip install --no-cache-dir -r requirements.txt

# 4. Install Custom Nodes from your list + pre-install their requirements
WORKDIR /opt/custom_nodes

# We combine clones and pip installs to keep the image clean and verify stability
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    pip install --no-cache-dir -r comfyui_controlnet_aux/requirements.txt || true && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    python3 ComfyUI-Impact-Pack/install.py || true && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    pip install --no-cache-dir -r ComfyUI_essentials/requirements.txt || true && \
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone https://github.com/chrisgoringe/cg-use-everywhere.git && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    git clone https://github.com/djbielejeski/a-person-mask-generator.git && \
    pip install --no-cache-dir -r a-person-mask-generator/requirements.txt || true && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone https://github.com/gseth/ControlAltAI-Nodes.git && \
    git clone https://github.com/fairy-root/ComfyUI-Show-Text.git

# 5. Create Model Structure
RUN mkdir -p /opt/models/sams /opt/models/ultralytics/bbox /opt/models/ultralytics/segm \
    /opt/models/diffusion_models /opt/models/vae /opt/models/clip /opt/models/loras

# 6. Pre-download heavy models (Makes startup instant)
RUN aria2c -c -x 16 -s 16 -d /opt/models/sams -o sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth && \
    aria2c -c -x 16 -s 16 -d /opt/models/ultralytics/bbox -o face_yolov8m.pt https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt && \
    aria2c -c -x 16 -s 16 -d /opt/models/diffusion_models -o z_image_turbo_bf16.safetensors https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors && \
    aria2c -c -x 16 -s 16 -d /opt/models/vae -o ae.safetensors https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors && \
    aria2c -c -x 16 -s 16 -d /opt/models/clip -o qwen_3_4b.safetensors https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Final Safety Check: Force Numpy < 2 again
RUN pip install "numpy<2"

WORKDIR /workspace
EXPOSE 8188 8888
CMD ["/start.sh"]
