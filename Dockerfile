# ==========================================
# BASE: NVIDIA CUDA 12.8 (Blackwell Ready)
# ==========================================
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/app/venv/bin:$PATH"

# 1. System Dependencies
RUN apt-get update && apt-get install -y \
    python3.10 python3.10-venv python3-pip git wget \
    libgl1 libglib2.0-0 libgoogle-perftools4 \
    && rm -rf /var/lib/apt/lists/*

# 2. Setup Directory Structure
WORKDIR /app
RUN python3.10 -m venv venv
RUN pip install --upgrade pip wheel

# 3. Install Torch 2.6 (Nightly for CUDA 12.8 support)
# We use the nightly index to ensure 50-series support
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

# 4. Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git
WORKDIR /app/ComfyUI
RUN pip install -r requirements.txt

# 5. Install "Speed" & Utility Custom Nodes
WORKDIR /app/ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git

# Install requirements for custom nodes
WORKDIR /app/ComfyUI
RUN pip install -r custom_nodes/ComfyUI-Manager/requirements.txt && \
    pip install -r custom_nodes/rgthree-comfy/requirements.txt && \
    pip install -r custom_nodes/ComfyUI-KJNodes/requirements.txt

# 6. Copy Our Entrypoint Script
COPY scripts/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 7. Environment Variables for Speed
# TCMalloc improves memory allocation speed
ENV LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4"
# Force 5090 optimizations
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

WORKDIR /app/ComfyUI
ENTRYPOINT ["/app/entrypoint.sh"]

