FROM yanwk/comfyui-boot:cu128-slim

USER root

# 1. Refresh repositories
# 2. Install using correct openSUSE Tumbleweed names
# netcat-openbsd is correct, but we'll ensure it's pulled cleanly.
# libGL1 is provided by Mesa-libGL1.
RUN zypper -n ref && \
    zypper -n in --no-recommends \
    curl unzip fuse3 ca-certificates \
    Mesa-libGL1 libglib-2_0-0 \
    gcc-c++ ninja \
    netcat-openbsd \
    && zypper clean -a

# 3. Standalone Rclone
RUN curl https://rclone.org/install.sh | bash

COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

EXPOSE 8188 5572

# RTX 5090 Blackwell Optimization
ENV CLI_ARGS="--listen --port 8188 --fast --use-sage-attention --bf16-unet --highvram"

ENTRYPOINT ["/app/entrypoint.sh"]
