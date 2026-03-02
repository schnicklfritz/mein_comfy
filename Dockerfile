# ==========================================
# mein_comfy - ComfyUI for Quickpod RTX 5090
# Base: ashleykza/comfyui:5090-py311-v0.3.36
#   CUDA 12.8, Python 3.11, Blackwell support
#   ComfyUI + Manager handled natively by base image
# ==========================================
FROM ashleykza/comfyui:5090-py311-v0.3.36

# B2 credentials - set in Quickpod template env vars, never in image
# EXTRA_ARGS passed to ComfyUI main.py - override in Quickpod env vars
ENV EXTRA_ARGS="--fast --use-pytorch-cross-attention" \
    B2_KEY_ID="" \
    B2_APPLICATION_KEY="" \
    B2_BUCKET=""

# Copy our pre_start hook - runs before ComfyUI launches each session
COPY scripts/pre_start.sh /pre_start.sh
RUN chmod +x /pre_start.sh

# install_nodes.sh for adding custom nodes at build time (optional)
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/install_nodes.sh \
    && bash /app/install_nodes.sh

# ComfyUI accessible on port 3000 (nginx proxy -> internal 3001)
# Open port 3000 in Quickpod template
EXPOSE 3000
