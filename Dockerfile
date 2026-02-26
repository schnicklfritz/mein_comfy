# ==========================================
# BASE: CUDA 12.8 Blackwell-Ready (openSUSE)
# ==========================================
FROM yanwk/comfyui-boot:cu128-slim

USER root

# 1. Install Build Essentials for Blackwell Kernel JIT
# openSUSE uses 'devel_basis' for compilers; 'ninja' is for SageAttention
RUN zypper --non-interactive refresh && \
    zypper --non-interactive install -t pattern devel_basis && \
    zypper --non-interactive install git ninja && \
    zypper clean --all

# 2. Copy Setup Scripts (Matching your local paths)
COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/install_nodes.sh /app/install_nodes.sh
RUN chmod +x /app/*.sh

# 3. Environment & Blackwell Architecture Flags
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    TORCH_CUDA_ARCH_LIST="12.0" \
    # Merged Blackwell arguments from your template
    CLI_ARGS="--listen --port 8188 --bf16-unet --highvram --use-sage-attention --weight-streaming --dont-upcast-attention"

# 4. Launch
ENTRYPOINT ["/app/entrypoint.sh"]
