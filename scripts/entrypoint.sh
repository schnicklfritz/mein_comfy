#!/bin/bash
set -e

echo "🚀 Starting mein_comfy (5090 Edition / yanwk base)..."

# --- 1. Define Symlinks (Same logic, new paths) ---
declare -A SYMLINKS
SYMLINKS=(
    ["models/checkpoints"]="checkpoints"
    ["models/loras"]="loras"
    ["models/vae"]="vae"
    ["models/clip"]="text_encoder"
    ["models/diffusion_models"]="diffusion_models"
    ["models/upscale_models"]="upscale_models"
    ["models/controlnet"]="controlnet"
    ["models/embeddings"]="embeddings"
    ["input"]="input"
    ["output"]="output"
)

# Persistent Root
PERSISTENT_ROOT="/workspace/ComfyUI_Data"
mkdir -p "$PERSISTENT_ROOT"

# --- 2. Smart Linking ---
for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET_NAME="${SYMLINKS[$INTERNAL_PATH]}"
    HOST_PATH="$PERSISTENT_ROOT/$TARGET_NAME"
    CONTAINER_PATH="/root/ComfyUI/$INTERNAL_PATH"  # <--- CHANGED for yanwk base

    # Create Host Path
    if [ ! -d "$HOST_PATH" ]; then
        mkdir -p "$HOST_PATH"
        # Create subfolders for heavy models
        if [[ "$TARGET_NAME" == "checkpoints" || "$TARGET_NAME" == "diffusion_models" ]]; then
            mkdir -p "$HOST_PATH/wan2.1" "$HOST_PATH/sdxl"
        fi
    fi

    # Safe Move
    if [ -d "$CONTAINER_PATH" ] && [ ! -L "$CONTAINER_PATH" ]; then
        if [ -n "$(ls -A $CONTAINER_PATH)" ]; then
            echo "   📦 Moving files from $INTERNAL_PATH..."
            cp -rn "$CONTAINER_PATH"/* "$HOST_PATH/" || true
        fi
        rm -rf "$CONTAINER_PATH"
    fi

    # Link
    if [ ! -L "$CONTAINER_PATH" ]; then
        ln -s "$HOST_PATH" "$CONTAINER_PATH"
    fi
done

# --- 3. Launch (Using the Base Image's Method) ---
echo "✅ Launching ComfyUI..."
cd /root/ComfyUI
# We use the CLI_ARGS env var we set in Dockerfile
exec python3 main.py $CLI_ARGS
