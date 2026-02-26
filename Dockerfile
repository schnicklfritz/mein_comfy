FROM yanwk/comfyui-boot:cu128-slim

USER root

# 1. Refresh repositories and install openSUSE versions of your tools
RUN zypper -n ref && \
    zypper -n in --no-recommends \
    curl unzip fuse3 ca-certificates \
    libGL1 libglib-2_0-0 \
    gcc-c++ ninja \
    netcat-openbsd \
    && zypper clean -a

# 2. Standalone Rclone
RUN curl https://rclone.org/install.sh | bash

COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

EXPOSE 8188 5572

# RTX 5090 Blackwell Optimization
# --bf16-unet: Mandatory to keep Flux/Chroma in VRAM (32GB)
# --use-sage-attention: Native Blackwell acceleration
ENV CLI_ARGS="--listen --port 8188 --fast --use-sage-attention --bf16-unet --highvram"

ENTRYPOINT ["/app/entrypoint.sh"]
