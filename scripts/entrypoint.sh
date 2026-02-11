#!/bin/bash
set -e

echo "🚀 Starting mein_comfy (5090 Edition)..."

# --- 1. Define Map: Internal Path -> Persistent Folder Name ---
declare -A SYMLINKS
SYMLINKS=(
    ["models/checkpoints"]="checkpoints"
    ["models/loras"]="loras"
    ["models/vae"]="vae"
    ["models/clip"]="text_encoder"  # Renaming clip to text_encoder
    ["models/diffusion_models"]="diffusion_models"
    ["models/upscale_models"]="upscale_models"
    ["models/controlnet"]="controlnet"
    ["models/embeddings"]="embeddings"
    ["input"]="input"
    ["output"]="output"
)

# Base persistent directory
PERSISTENT_ROOT="/workspace/ComfyUI_Data"
mkdir -p "$PERSISTENT_ROOT"

# --- 2. Smart Linking Loop ---
for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET_NAME="${SYMLINKS[$INTERNAL_PATH]}"
    HOST_PATH="$PERSISTENT_ROOT/$TARGET_NAME"
    CONTAINER_PATH="/app/ComfyUI/$INTERNAL_PATH"

    # A. Ensure Host Path Exists
    if [ ! -d "$HOST_PATH" ]; then
        echo "   Creating persistent folder: $TARGET_NAME"
        mkdir -p "$HOST_PATH"
        
        # Create subfolders for heavy models
        if [[ "$TARGET_NAME" == "checkpoints" || "$TARGET_NAME" == "diffusion_models" ]]; then
            mkdir -p "$HOST_PATH/wan2.1" "$HOST_PATH/sdxl" "$HOST_PATH/flux"
        fi
    fi

    # B. Handle Existing Container Data (The "Safe Move")
    # If the container folder exists and is NOT a symlink...
    if [ -d "$CONTAINER_PATH" ] && [ ! -L "$CONTAINER_PATH" ]; then
        # Check if it has files
        if [ -n "$(ls -A $CONTAINER_PATH)" ]; then
            echo "   📦 Moving default files from $INTERNAL_PATH to persistent storage..."
            # Move contents to host path, skipping overwrites or merging
            cp -rn "$CONTAINER_PATH"/* "$HOST_PATH/" || true
        fi
        # Remove the directory so we can replace it with a link
        rm -rf "$CONTAINER_PATH"
    fi

    # C. Create Symlink
    if [ ! -L "$CONTAINER_PATH" ]; then
        echo "   🔗 Linking $INTERNAL_PATH -> $HOST_PATH"
        ln -s "$HOST_PATH" "$CONTAINER_PATH"
    fi
done

# --- 3. Launch ComfyUI ---
echo "✅ Setup Complete. Launching ComfyUI on Port 8188..."
# --fast: Skips some startup checks
# --highvram: Optimizes for 24GB+ cards
exec python3 main.py --listen --port 8188 --fast --highvram
