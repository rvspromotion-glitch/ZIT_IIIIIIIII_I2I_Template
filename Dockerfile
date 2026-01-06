# Using your verified working base image
FROM runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/opt/ComfyUI
ENV PYTHONUNBUFFERED=1

# 1. Install System Dependencies (Added aria2 for faster downloads)
RUN apt-get update && apt-get install -y \
    git wget curl aria2 libgl1 libglib2.0-0 ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 2. Prevent Dependency Drift & NumPy 2.0 errors
RUN pip install --no-cache-dir "numpy<2" "protobuf<5" "transformers>=4.44.2" \
    "tokenizers>=0.19" "safetensors" "mediapipe==0.10.14" "jupyterlab" \
    "sentencepiece" "ultralytics" "onnxruntime-gpu"

# 3. Setup ComfyUI Core in /opt (Safe from Volume wipes)
WORKDIR /opt/ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    pip install --no-cache-dir -r requirements.txt

# 4. Install Custom Nodes from your list
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

# 5. Pre-install all node requirements during the build (Saves 10 mins on boot)
RUN find . -maxdepth 2 -name "requirements.txt" -exec pip install --no-cache-dir -r {} \;

# 6. Create Model Structure & Pre-download BBOX/SAM (Instant Startup)
RUN mkdir -p /opt/ComfyUI/models/sams /opt/ComfyUI/models/ultralytics/bbox \
    /opt/ComfyUI/models/diffusion_models /opt/ComfyUI/models/vae /opt/ComfyUI/models/clip

RUN aria2c -c -x 16 -s 16 -d /opt/ComfyUI/models/sams -o sam_vit_b_01ec64.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth && \
    aria2c -c -x 16 -s 16 -d /opt/ComfyUI/models/ultralytics/bbox -o face_yolov8m.pt https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt && \
    aria2c -c -x 16 -s 16 -d /opt/ComfyUI/models/diffusion_models -o z_image_turbo_bf16.safetensors https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors && \
    aria2c -c -x 16 -s 16 -d /opt/ComfyUI/models/vae -o ae.safetensors https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors && \
    aria2c -c -x 16 -s 16 -d /opt/ComfyUI/models/clip -o qwen_3_4b.safetensors https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors

# 7. Final stability check
RUN pip install "numpy<2"

COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /workspace
EXPOSE 8188 8888
CMD ["/start.sh"]
