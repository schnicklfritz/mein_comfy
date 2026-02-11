#!/bin/bash
set -e

COMFY_DIR="/root/ComfyUI"
MANAGER_DIR="$COMFY_DIR/custom_nodes/ComfyUI-Manager"

echo "🚀 Starting mein_comfy (Minimal Base)..."

# --- 1. Self-Healing: Install ComfyUI if missing ---
if [ ! -f "$COMFY_DIR/main.py" ]; then
    echo "⚠️ ComfyUI not found in $COMFY_DIR. Installing..."
    
    if [ -d "/app/ComfyUI" ]; then
        echo "   Found at /app/ComfyUI. Moving..."
        cp -r /app/ComfyUI "$COMFY_DIR"
    elif [ -d "/ComfyUI" ]; then
        echo "   Found at /ComfyUI. Moving..."
        cp -r /ComfyUI "$COMFY_DIR"
    else
        echo "   Downloading fresh ComfyUI..."
        git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
    fi
fi

# --- 2. Self-Healing: Install Manager if missing ---
if [ ! -d "$MANAGER_DIR" ]; then
    echo "⚠️ ComfyUI-Manager not found. Installing..."
    mkdir -p "$COMFY_DIR/custom_nodes"
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
fi

# --- 2.5 [FIX] Force Update Frontend Package ---
echo "🔄 Updating ComfyUI Frontend to match Backend..."
pip install --upgrade comfyui-frontend-package

# --- 3. Define Symlinks (Persistent Storage) ---
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

# --- 4. Smart Linking Loop ---
for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET_NAME="${SYMLINKS[$INTERNAL_PATH]}"
    HOST_PATH="$PERSISTENT_ROOT/$TARGET_NAME"
    CONTAINER_PATH="$COMFY_DIR/$INTERNAL_PATH"
    CONTAINER_PARENT=$(dirname "$CONTAINER_PATH")

    if [ ! -d "$HOST_PATH" ]; then
        if [[ "$TARGET_NAME" == "checkpoints" || "$TARGET_NAME" == "diffusion_models" ]]; then
            mkdir -p "$HOST_PATH/wan2.1" "$HOST_PATH/sdxl" "$HOST_PATH/flux"
        fi
        mkdir -p "$HOST_PATH"
    fi

    if [ ! -d "$CONTAINER_PARENT" ]; then
        mkdir -p "$CONTAINER_PARENT"
    fi

    if [ -d "$CONTAINER_PATH" ] && [ ! -L "$CONTAINER_PATH" ]; then
        if [ -n "$(ls -A $CONTAINER_PATH 2>/dev/null)" ]; then
            echo "   📦 Moving default files from $INTERNAL_PATH..."
            cp -rn "$CONTAINER_PATH"/* "$HOST_PATH/" 2>/dev/null || true
        fi
        rm -rf "$CONTAINER_PATH"
    fi

    if [ ! -L "$CONTAINER_PATH" ]; then
        echo "   🔗 Linking $INTERNAL_PATH -> $HOST_PATH"
        ln -s "$HOST_PATH" "$CONTAINER_PATH"
    fi
done

# --- 5. Launch ---
echo "✅ Setup Complete. Launching ComfyUI..."
cd "$COMFY_DIR"
exec python3 main.py $CLI_ARGS
