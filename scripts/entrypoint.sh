#!/bin/bash
set -e

echo "🚀 Starting mein_comfy (Minimal Base)..."

# --- 1. Define Symlinks ---
# Map internal ComfyUI paths to your persistent folders in /workspace
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

# Base persistent directory (Mounted Volume)
PERSISTENT_ROOT="/workspace/ComfyUI_Data"
mkdir -p "$PERSISTENT_ROOT"

# --- 2. Smart Linking Loop ---
for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET_NAME="${SYMLINKS[$INTERNAL_PATH]}"
    HOST_PATH="$PERSISTENT_ROOT/$TARGET_NAME"
    CONTAINER_PATH="/root/ComfyUI/$INTERNAL_PATH"
    CONTAINER_PARENT=$(dirname "$CONTAINER_PATH")

    # A. Create Host Path if missing
    if [ ! -d "$HOST_PATH" ]; then
        # Create subfolders for heavy models to stay organized
        if [[ "$TARGET_NAME" == "checkpoints" || "$TARGET_NAME" == "diffusion_models" ]]; then
            mkdir -p "$HOST_PATH/wan2.1" "$HOST_PATH/sdxl" "$HOST_PATH/flux"
        fi
        mkdir -p "$HOST_PATH"
    fi

    # B. [FIX] Create Container Parent Directory if missing
    # Prevents "ln: failed to create symbolic link... No such file or directory"
    if [ ! -d "$CONTAINER_PARENT" ]; then
        echo "   Creating parent dir: $CONTAINER_PARENT"
        mkdir -p "$CONTAINER_PARENT"
    fi

    # C. Handle Existing Container Data (Safe Move)
    if [ -d "$CONTAINER_PATH" ] && [ ! -L "$CONTAINER_PATH" ]; then
        if [ -n "$(ls -A $CONTAINER_PATH 2>/dev/null)" ]; then
            echo "   📦 Moving default files from $INTERNAL_PATH to persistent storage..."
            cp -rn "$CONTAINER_PATH"/* "$HOST_PATH/" 2>/dev/null || true
        fi
        rm -rf "$CONTAINER_PATH"
    fi

    # D. Create Symlink
    if [ ! -L "$CONTAINER_PATH" ]; then
        echo "   🔗 Linking $INTERNAL_PATH -> $HOST_PATH"
        ln -s "$HOST_PATH" "$CONTAINER_PATH"
    fi
done

# --- 3. Launch ComfyUI ---
echo "✅ Setup Complete. Launching ComfyUI on Port 8188..."
cd /root/ComfyUI
# Use exec to ensure ComfyUI gets PID 1 signals
exec python3 main.py $CLI_ARGS
