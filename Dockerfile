FROM runpod/pytorch:2.1.0-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_PATH=/workspace/ComfyUI

RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    xformers \
    ultralytics

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188

CMD ["/start.sh"]
