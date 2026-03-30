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
STAGING_DIR="/opt/comfyui-staging"
# Venv lives inside ComfyUI dir - matches start_comfyui.sh:
#   cd /workspace/ComfyUI && source venv/bin/activate
VENV_PIP="$COMFY_DIR/venv/bin/pip"

# ── Helper: update a shallow-cloned git repo ─────────────────────────────────
# git pull fails on --depth=1 clones; fetch+reset is safe for both shallow/full
git_update() {
    local dir="$1"
    local label="$2"
    if [ -d "$dir/.git" ]; then
        echo "[INFO] Updating $label..."
        git -C "$dir" fetch --depth=1 origin HEAD 2>&1 | sed 's/^/  /' \
            || { echo "[WARN] $label fetch failed - continuing with current version"; return 0; }
        git -C "$dir" reset --hard FETCH_HEAD 2>&1 | sed 's/^/  /' \
            || echo "[WARN] $label reset failed"
    else
        echo "[WARN] $label: not a git repo at $dir - skipping update"
    fi
}

# ── Helper: install requirements.txt if it exists ────────────────────────────
pip_install_req() {
    local req="$1"
    if [ -f "$req" ]; then
        echo "[INFO] pip install -r $req"
        "$VENV_PIP" install -q -r "$req" || echo "[WARN] pip install failed for $req"
    fi
}

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

# ── Deploy or update ComfyUI ─────────────────────────────────────────────────
if [ ! -f "$COMFY_DIR/main.py" ]; then
    # ── FIRST START: copy from build-time staging, then pull latest ──────────
    echo "[INFO] ComfyUI not found in /workspace - deploying from staging..."

    if [ -d "$STAGING_DIR" ]; then
        cp -a "$STAGING_DIR" "$COMFY_DIR"
        echo "[INFO] Staged copy complete"
    else
        echo "[WARN] Staging dir missing - cloning from scratch (slow path)..."
        git clone --depth=1 https://github.com/comfyanonymous/ComfyUI "$COMFY_DIR"
        git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager \
            "$COMFY_DIR/custom_nodes/ComfyUI-Manager"
    fi

    # Staging venv is pre-built - VENV_PIP now resolves correctly
    # Pull latest on top of staged copy (image may be days old at deploy time)
    git_update "$COMFY_DIR" "ComfyUI"
    git_update "$COMFY_DIR/custom_nodes/ComfyUI-Manager" "ComfyUI-Manager"

    echo "[INFO] Syncing pip deps after update..."
    pip_install_req "$COMFY_DIR/requirements.txt"
    pip_install_req "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt"

    echo "[INFO] ComfyUI first-start deploy complete"

else
    # ── SUBSEQUENT STARTS: update everything ─────────────────────────────────
    echo "[INFO] ComfyUI found - running updates..."

    git_update "$COMFY_DIR" "ComfyUI"
    git_update "$COMFY_DIR/custom_nodes/ComfyUI-Manager" "ComfyUI-Manager"

    echo "[INFO] Updating pip deps for ComfyUI core..."
    pip_install_req "$COMFY_DIR/requirements.txt"

    echo "[INFO] Updating pip deps for ComfyUI-Manager..."
    pip_install_req "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt"

    # ── Update all baked-in custom nodes' pip deps ───────────────────────────
    echo "[INFO] Updating pip deps for all custom nodes..."
    for req in "$COMFY_DIR/custom_nodes"/*/requirements.txt; do
        node_name=$(basename "$(dirname "$req")")
        echo "[INFO]   -> $node_name"
        pip_install_req "$req"
    done

    echo "[INFO] Update complete"
fi

# ── Symlink /workspace model dirs into ComfyUI ───────────────────────────────
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
    # Remove if it's a real dir or wrong/stale symlink
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

── COMFYUI-MANAGER WORKFLOW REGISTRY ──────────────────────────────
Manager is updated on every pod start (git pull + pip deps).
To install/update workflows: open Manager UI → "Install Workflows"
Workflows saved to /workspace/workflows/ (persists on stop).

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
├── ComfyUI/            updated on every pod start
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
├── workflows/          symlinked from ComfyUI - persists on stop
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
# NOTE: start.sh (base image) does NOT call start_comfyui.sh itself - this line is required
bash /start_comfyui.sh ${EXTRA_ARGS}
