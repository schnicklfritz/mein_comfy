#!/bin/bash
# ==========================================
# Optimized Entrypoint for Blackwell (sm_120)
# ==========================================

set -e

# 1. Hardware Check: Verify NVIDIA Driver version for Blackwell (sm_120)
if ! nvidia-smi | grep -q "570"; then
    echo "⚠️ Warning: Blackwell requires Driver 570+. Attempting launch anyway..."
fi

# 2. Environment Alignment
# Ensure CLI_ARGS is populated from your Dockerfile/Template
export CLI_ARGS=${CLI_ARGS:-"--listen --port 8188"}
export TORCH_CUDA_ARCH_LIST="12.0"

# 3. Application Deployment
# If /root/ComfyUI is empty, copy the bundled version from the image
if [ ! -d "/root/ComfyUI" ]; then
    echo "📦 Initializing ComfyUI in persistent volume..."
    cp -r /runner-scripts/ComfyUI /root/
fi

# 4. Trigger Your Custom Node Script
if [ -f "/app/install_nodes.sh" ]; then
    echo "🛠️ Running custom node installation..."
    bash /app/install_nodes.sh
fi

# 5. Launch ComfyUI
# Using 'exec' ensures the Python process receives the Docker signals directly
echo "🚀 Starting ComfyUI with Blackwell Optimizations..."
cd /root/ComfyUI
exec python3 main.py $CLI_ARGS
