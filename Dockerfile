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

# Install packages including Jupyter and sageattention
RUN pip install --no-cache-dir \
    xformers==0.0.23 \
    ultralytics \
    jupyter \
    notebook \
    sageattention

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports for ComfyUI and Jupyter
EXPOSE 8188 8888

CMD ["/start.sh"]
