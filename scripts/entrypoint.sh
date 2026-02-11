#!/bin/bash
set -e
echo "🚀 Starting mein_comfy (Minimal Base)..."

# Symlinks (Same logic)
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

PERSISTENT_ROOT="/workspace/ComfyUI_Data"
mkdir -p "$PERSISTENT_ROOT"

for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET_NAME="${SYMLINKS[$INTERNAL_PATH]}"
    HOST_PATH="$PERSISTENT_ROOT/$TARGET_NAME"
    CONTAINER_PATH="/root/ComfyUI/$INTERNAL_PATH"

    [ ! -d "$HOST_PATH" ] && mkdir -p "$HOST_PATH"

    if [ -d "$CONTAINER_PATH" ] && [ ! -L "$CONTAINER_PATH" ]; then
        [ -n "$(ls -A $CONTAINER_PATH)" ] && cp -rn "$CONTAINER_PATH"/* "$HOST_PATH/" 2>/dev/null
        rm -rf "$CONTAINER_PATH"
    fi

    [ ! -L "$CONTAINER_PATH" ] && ln -s "$HOST_PATH" "$CONTAINER_PATH"
done

echo "✅ Launching ComfyUI..."
cd /root/ComfyUI
exec python3 main.py $CLI_ARGS
