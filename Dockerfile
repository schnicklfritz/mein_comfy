# ==========================================
# mein_comfy - ComfyUI for Quickpod
# Base: yanwk/comfyui-boot:cu128-slim
# ==========================================
FROM yanwk/comfyui-boot:cu128-slim

USER root

# Copy scripts
COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

# Environment
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    CLI_ARGS="--listen --port 8188 --fast"

EXPOSE 8188

ENTRYPOINT ["/app/entrypoint.sh"]
