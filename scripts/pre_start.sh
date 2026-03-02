#!/bin/bash
# /pre_start.sh
# mein_comfy pre-start hook for ashleykza/comfyui base image
# Called automatically by the base image before ComfyUI launches
# Set B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET in Quickpod template env vars

set -e

echo "########################################"
echo "  mein_comfy pre_start running..."
echo "########################################"

COMFY_DIR="/workspace/ComfyUI"

# ── Auto-configure rclone B2 from Quickpod env vars ──────────────────────────
if [ -n "${B2_KEY_ID}" ] && [ -n "${B2_APPLICATION_KEY}" ]; then
    export RCLONE_CONFIG_B2_TYPE=b2
    export RCLONE_CONFIG_B2_ACCOUNT="${B2_KEY_ID}"
    export RCLONE_CONFIG_B2_KEY="${B2_APPLICATION_KEY}"
    echo "[INFO] rclone B2 auto-configured from environment"
    echo "[INFO] B2 bucket: ${B2_BUCKET:-<not set>}"
else
    echo "[WARN] B2_KEY_ID / B2_APPLICATION_KEY not set - rclone B2 not configured"
    echo "[WARN] Set these in Quickpod template environment variables"
fi

# ── /workspace mount check ────────────────────────────────────────────────────
if ! mountpoint -q /workspace 2>/dev/null; then
    echo "[WARN] /workspace is NOT a mounted volume. Data will not persist."
fi

# ── Create /workspace folder structure ───────────────────────────────────────
echo "[INFO] Creating /workspace folder structure..."
mkdir -p \
    /workspace/models/checkpoints \
    /workspace/models/loras \
    /workspace/models/vae \
    /workspace/models/clip \
    /workspace/models/diffusion_models \
    /workspace/models/upscale_models \
    /workspace/models/controlnet \
    /workspace/models/embeddings \
    /workspace/models/text_encoders \
    /workspace/models/audio_encoders \
    /workspace/models/clip_vision \
    /workspace/models/unet \
    /workspace/models/diffusers \
    /workspace/models/model_patches \
    /workspace/models/photomaker \
    /workspace/models/style_models \
    /workspace/models/gligen \
    /workspace/models/hypernetworks \
    /workspace/models/latent_upscale_models \
    /workspace/models/vae_approx \
    /workspace/input \
    /workspace/output \
    /workspace/workflows \
    /workspace/logs

# ── Clone ComfyUI if missing, update if present ──────────────────────────────
if [ ! -f "$COMFY_DIR/main.py" ]; then
    echo "[INFO] ComfyUI not found, cloning..."
    rm -rf "$COMFY_DIR"
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI "$COMFY_DIR"

    echo "[INFO] Creating venv and installing requirements..."
    cd "$COMFY_DIR"
    python3.11 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt

    echo "[INFO] Installing ComfyUI-Manager..."
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager         "$COMFY_DIR/custom_nodes/ComfyUI-Manager"
    pip install -r "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt"
    deactivate
    echo "[INFO] ComfyUI install complete"
else
    echo "[INFO] Updating ComfyUI core..."
    cd "$COMFY_DIR" && git pull || echo "[WARN] ComfyUI update failed"

    echo "[INFO] Updating ComfyUI-Manager..."
    cd "$COMFY_DIR/custom_nodes/ComfyUI-Manager" && git pull || echo "[WARN] Manager update failed"
fi

# ── Symlink /workspace model dirs into ComfyUI ───────────────────────────────
# Wait for base image to finish setting up ComfyUI before symlinking
echo "[INFO] Setting up symlinks..."

declare -A SYMLINKS=(
    ["models/checkpoints"]="/workspace/models/checkpoints"
    ["models/loras"]="/workspace/models/loras"
    ["models/vae"]="/workspace/models/vae"
    ["models/clip"]="/workspace/models/clip"
    ["models/diffusion_models"]="/workspace/models/diffusion_models"
    ["models/upscale_models"]="/workspace/models/upscale_models"
    ["models/controlnet"]="/workspace/models/controlnet"
    ["models/embeddings"]="/workspace/models/embeddings"
    ["models/text_encoders"]="/workspace/models/text_encoders"
    ["models/audio_encoders"]="/workspace/models/audio_encoders"
    ["models/clip_vision"]="/workspace/models/clip_vision"
    ["models/unet"]="/workspace/models/unet"
    ["models/diffusers"]="/workspace/models/diffusers"
    ["models/model_patches"]="/workspace/models/model_patches"
    ["models/photomaker"]="/workspace/models/photomaker"
    ["models/style_models"]="/workspace/models/style_models"
    ["models/gligen"]="/workspace/models/gligen"
    ["models/hypernetworks"]="/workspace/models/hypernetworks"
    ["models/latent_upscale_models"]="/workspace/models/latent_upscale_models"
    ["models/vae_approx"]="/workspace/models/vae_approx"
    ["input"]="/workspace/input"
    ["output"]="/workspace/output"
    ["user/default/workflows"]="/workspace/workflows"
)

for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET="${SYMLINKS[$INTERNAL_PATH]}"
    LINK="$COMFY_DIR/$INTERNAL_PATH"
    mkdir -p "$(dirname "$LINK")"
    # Remove if it's a real dir or wrong symlink
    [ -d "$LINK" ] && [ ! -L "$LINK" ] && rm -rf "$LINK"
    [ -L "$LINK" ] && rm -f "$LINK"
    ln -sf "$TARGET" "$LINK"
    echo "[INFO] Linked: $LINK -> $TARGET"
done

# ── Write README.txt ──────────────────────────────────────────────────────────
cat > /workspace/README.txt << 'READMEEOF'
########################################
mein_comfy - Storage Reference
########################################

NOTE: This pod is ephemeral. All data is lost on pod destroy.
      Use B2 to persist models and outputs between sessions.

── B2 CREDENTIALS ─────────────────────────────────────────────────
Set in Quickpod template environment variables (never in the image):
  B2_KEY_ID          = your Backblaze keyID
  B2_APPLICATION_KEY = your Backblaze applicationKey
  B2_BUCKET          = your bucket name

rclone is auto-configured on pod start if these are set.
No need to run rclone config manually.

── ARIA2 - DOWNLOAD FROM HUGGINGFACE ──────────────────────────────
# Download to specific folder
aria2c -x16 -s16 -d /workspace/models/checkpoints/ "https://huggingface.co/USER/REPO/resolve/main/model.safetensors"

# Download private HuggingFace model (requires HF token)
aria2c -x16 -s16 \
  --header="Authorization: Bearer YOUR_HF_TOKEN" \
  -d /workspace/models/checkpoints/ \
  "https://huggingface.co/USER/REPO/resolve/main/model.safetensors"

── RCLONE - B2 OPERATIONS ─────────────────────────────────────────

# Download folder from B2
rclone copy b2:${B2_BUCKET}/checkpoints/ /workspace/models/checkpoints/ --transfers 16 --progress

# Upload folder to B2
rclone copy /workspace/output/ b2:${B2_BUCKET}/output/ --transfers 16 --progress

# List files in B2
rclone ls b2:${B2_BUCKET}/checkpoints/

── PORTS ──────────────────────────────────────────────────────────
3000  ComfyUI (nginx proxy -> internal 3001)
8000  App Manager (start/stop ComfyUI)
7777  File browser
2999  SSH

── RESTART ComfyUI ────────────────────────────────────────────────
# Kill ComfyUI (port 3001 process)
pkill -f "main.py"

# Restart using the same script the image uses
bash /start_comfyui.sh ${EXTRA_ARGS}

# Or use the App Manager web UI on port 8000

── LOGS ───────────────────────────────────────────────────────────
tail -f /workspace/logs/comfyui.log

── FOLDER MAP ─────────────────────────────────────────────────────
/workspace/
├── ComfyUI/            base image managed - do not edit directly
├── models/
│   ├── checkpoints/    symlinked into ComfyUI
│   ├── loras/
│   ├── vae/
│   ├── clip/
│   ├── diffusion_models/
│   ├── upscale_models/
│   ├── controlnet/
│   ├── embeddings/
│   ├── text_encoders/
│   ├── audio_encoders/
│   ├── clip_vision/
│   ├── unet/
│   ├── diffusers/
│   ├── model_patches/
│   ├── photomaker/
│   ├── style_models/
│   ├── gligen/
│   ├── hypernetworks/
│   ├── latent_upscale_models/
│   └── vae_approx/
├── input/
├── output/
├── workflows/
├── logs/
│   └── comfyui.log
└── README.txt

########################################
READMEEOF
echo "[INFO] README.txt written to /workspace/README.txt"

echo "########################################"
echo "  mein_comfy pre_start complete."
echo "  Launching ComfyUI..."
echo "########################################"

# start_comfyui.sh handles: venv activation, port 3001, logging to /workspace/logs/comfyui.log
# EXTRA_ARGS is passed through as positional args
bash /start_comfyui.sh ${EXTRA_ARGS}
