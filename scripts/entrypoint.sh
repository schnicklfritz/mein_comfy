#!/bin/bash
set -e

COMFY_DIR="/root/ComfyUI"

echo "🚀 Starting mein_comfy..."

# --- Symlinks (Persistent Storage → Backblaze staging) ---
declare -A SYMLINKS
SYMLINKS=(
    ["models/checkpoints"]="checkpoints"
    ["models/loras"]="loras"
    ["models/vae"]="vae"
    ["models/clip"]="text_encoders"
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
    CONTAINER_PATH="$COMFY_DIR/$INTERNAL_PATH"
    CONTAINER_PARENT=$(dirname "$CONTAINER_PATH")

    mkdir -p "$HOST_PATH"
    mkdir -p "$CONTAINER_PARENT"

    if [ -d "$CONTAINER_PATH" ] && [ ! -L "$CONTAINER_PATH" ]; then
        cp -rn "$CONTAINER_PATH"/* "$HOST_PATH/" 2>/dev/null || true
        rm -rf "$CONTAINER_PATH"
    fi

    if [ ! -L "$CONTAINER_PATH" ]; then
        ln -s "$HOST_PATH" "$CONTAINER_PATH"
    fi
done

echo "✅ Launching ComfyUI..."
cd "$COMFY_DIR"
exec python3 main.py ${CLI_ARGS:-}

