# ==========================================
# mein_comfy - ComfyUI for Quickpod RTX 5090
# Base: yanwk/comfyui-boot:cu129-slim
#   cu129 = Turing → Blackwell (RTX 50xx) support
#   cu128 stopped receiving updates
# ==========================================
FROM yanwk/comfyui-boot:cu129-slim

USER root

# Useful tools missing from slim image
RUN zypper --non-interactive install -y \
    tini \
    procps \
    lsof \
    && zypper clean --all

COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

# Bundle ComfyUI + Manager into image so entrypoint cp is instant (no runtime clone)
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI \
        /default-comfyui-bundle/ComfyUI \
    && pip install -r /default-comfyui-bundle/ComfyUI/requirements.txt \
    && git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager \
        /default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-Manager \
    && pip install -r /default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# tini as PID 1 so ComfyUI can be killed/restarted without killing the pod
# CLI_ARGS passed through to ComfyUI - override in Quickpod env vars
# B2 credentials - set B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET in Quickpod env
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    CLI_ARGS="--listen --port 8188 --fast --enable-manager"

EXPOSE 8188

ENTRYPOINT ["tini", "--", "/app/entrypoint.sh"]
