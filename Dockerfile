FROM yanwk/comfyui-boot:cu128-slim

USER root

# Install system dependencies + Standalone Rclone
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip fuse3 ca-certificates libgl1 libglib2.0-0 \
    && curl https://rclone.org/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

EXPOSE 8188 5572

# RTX 5090 Optimization Environment
# --bf16-unet: Mandatory for Flux (Chroma HD) to stay under 32GB VRAM
# --use-sage-attention: Native Blackwell acceleration
ENV CLI_ARGS="--listen --port 8188 --fast --use-sage-attention --bf16-unet --highvram"

ENTRYPOINT ["/app/entrypoint.sh"]
