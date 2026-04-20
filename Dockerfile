# ==========================================
# mein_comfy - ComfyUI for Quickpod RTX 5090
# Base: ashleykza/comfyui:5090-py311-v0.3.36
#   CUDA 12.8, Python 3.11, Blackwell support
#
# Build-time: ComfyUI + Manager staged to /opt/comfyui-staging
#   with venv at /opt/comfyui-staging/venv (mirrors /workspace/ComfyUI/venv)
# Runtime: pre_start.sh deploys staging → /workspace/ComfyUI on fresh pod
#   On restart: git fetch+reset + pip sync on all nodes
#
# start_comfyui.sh (base image) expects:
#   cd /workspace/ComfyUI && source venv/bin/activate && python3 main.py
# ==========================================
FROM ashleykza/comfyui:cu128-py311-v0.18.2

# B2 credentials - set in Quickpod template env vars, never in image
# EXTRA_ARGS passed to ComfyUI main.py - override in Quickpod env vars
ENV EXTRA_ARGS="--fast --disable-xformers --reserve-vram 0.5 --cuda-malloc" \
    PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:512,roundup_power2_divisions:4" \
    CUDA_MODULE_LOADING="LAZY" \
    TORCH_CUDNN_V8_API_ENABLED=1 \
    TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1 \
    NVIDIA_TF32_OVERRIDE=1 \
    B2_KEY_ID="" \
    B2_APPLICATION_KEY="" \
    B2_BUCKET=""

# ── Build-time: stage ComfyUI + Manager + venv ───────────────────────────────
# /workspace does not exist at build time.
# Venv is built inside staging dir to mirror the live path:
#   /opt/comfyui-staging/venv → becomes → /workspace/ComfyUI/venv
# start_comfyui.sh does: cd /workspace/ComfyUI && source venv/bin/activate
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI /opt/comfyui-staging \
    && git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager \
        /opt/comfyui-staging/custom_nodes/ComfyUI-Manager \
    && cd /opt/comfyui-staging \
    && python3.11 -m venv venv \
    && venv/bin/pip install --upgrade pip --quiet \
    && venv/bin/pip install --quiet -r requirements.txt \
    && venv/bin/pip install --quiet \
        -r custom_nodes/ComfyUI-Manager/requirements.txt

# Copy our hooks
COPY scripts/pre_start.sh /pre_start.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /pre_start.sh /app/install_nodes.sh \
    && bash /app/install_nodes.sh

# ComfyUI accessible on port 3000 (nginx proxy -> internal 3001)
EXPOSE 3000
