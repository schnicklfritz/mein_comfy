# ==========================================
# BASE: Proven CUDA 12.8 Base (Minimal)
# ==========================================
FROM yanwk/comfyui-boot:cu128-slim

# This image includes:
# - ComfyUI
# - ComfyUI-Manager (already baked in)
# - Nothing else

# 1. Copy Setup Scripts
USER root
COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

# 2. Environment
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    CLI_ARGS="--listen --port 8188 --fast"

ENTRYPOINT ["/app/entrypoint.sh"]

