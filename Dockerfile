# ==========================================
# BASE: Proven CUDA 12.8 ComfyUI Image
# ==========================================
FROM yanwk/comfyui-boot:cu128-slim

# The base image already has:
# - CUDA 12.8
# - PyTorch (Correct version for 5090)
# - ComfyUI + ComfyUI Manager
# - Common deps (ffmpeg, git, etc)

# 1. Install YOUR Must-Have Custom Nodes
WORKDIR /root/ComfyUI/custom_nodes
RUN git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git

# Install requirements for them
WORKDIR /root/ComfyUI
RUN pip install -r custom_nodes/rgthree-comfy/requirements.txt && \
    pip install -r custom_nodes/ComfyUI-KJNodes/requirements.txt

# 2. Copy YOUR Setup Script
# We use /app/entrypoint.sh to keep it distinct
USER root
COPY scripts/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 3. Environment Overrides
# Ensure we see all GPUs and have correct capabilities
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,video,display \
    CLI_ARGS="--listen --port 8188 --fast --highvram"

# 4. Entrypoint
# We hijack the entrypoint to run YOUR symlink logic first, 
# then launch ComfyUI using the base image's environment.
ENTRYPOINT ["/app/entrypoint.sh"]
