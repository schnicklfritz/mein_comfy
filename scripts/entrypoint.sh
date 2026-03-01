#!/bin/bash
# /app/entrypoint.sh
# mein_comfy entrypoint for Quickpod (ephemeral pod)
# tini is PID 1 - ComfyUI can be killed and restarted safely
# Set B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET in Quickpod template env vars

set -e

echo "########################################"
echo "  mein_comfy starting..."
echo "########################################"

# ── Python environment ────────────────────────────────────────────────────────
export PYTHONPYCACHEPREFIX="/root/.cache/pycache"
export PIP_USER=true
export PATH="${PATH}:/root/.local/bin"
export PIP_ROOT_USER_ACTION=ignore

COMFY_DIR="/root/ComfyUI"

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
    echo "[WARN] /workspace is NOT a mounted volume."
fi
mkdir -p /workspace

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
    /workspace/input \
    /workspace/output \
    /workspace/workflows

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
Max speed: 16 connections, split into 16 parts.

# Download to current folder (pwd)
aria2c -x16 -s16 "https://huggingface.co/USER/REPO/resolve/main/model.safetensors"

# Download to current folder with custom filename
aria2c -x16 -s16 -o "mymodel.safetensors" "https://huggingface.co/USER/REPO/resolve/main/model.safetensors"

# Download to specific folder
aria2c -x16 -s16 -d /workspace/models/checkpoints/ "https://huggingface.co/USER/REPO/resolve/main/model.safetensors"

# Download private HuggingFace model (requires HF token)
aria2c -x16 -s16 \
  --header="Authorization: Bearer YOUR_HF_TOKEN" \
  -d /workspace/models/checkpoints/ \
  "https://huggingface.co/USER/REPO/resolve/main/model.safetensors"

# Batch download - one URL per line in urls.txt
aria2c -x16 -s16 -i /workspace/urls.txt -d /workspace/models/checkpoints/

── RCLONE - DOWNLOAD FROM B2 ──────────────────────────────────────

# Download single file to current folder (pwd)
rclone copy b2:${B2_BUCKET}/checkpoints/model.safetensors .

# Download single file to specific folder
rclone copy b2:${B2_BUCKET}/checkpoints/model.safetensors /workspace/models/checkpoints/

# Download entire folder
rclone copy b2:${B2_BUCKET}/checkpoints/ /workspace/models/checkpoints/ --transfers 16 --progress

# Download only files not already present (skip existing)
rclone copy b2:${B2_BUCKET}/checkpoints/ /workspace/models/checkpoints/ --transfers 16 --progress --ignore-existing

── RCLONE - UPLOAD TO B2 ──────────────────────────────────────────

# Upload single file from current folder (pwd)
rclone copy ./model.safetensors b2:${B2_BUCKET}/checkpoints/

# Upload single file from specific path
rclone copy /workspace/models/checkpoints/model.safetensors b2:${B2_BUCKET}/checkpoints/

# Upload entire folder
rclone copy /workspace/output/ b2:${B2_BUCKET}/output/ --transfers 16 --progress

# Sync folder to B2 (WARNING: deletes files in B2 not present locally)
rclone sync /workspace/output/ b2:${B2_BUCKET}/output/ --transfers 16 --progress

── RCLONE - MANAGE FILES IN B2 ────────────────────────────────────

# List files in a B2 folder
rclone ls b2:${B2_BUCKET}/checkpoints/

# List folders only
rclone lsd b2:${B2_BUCKET}/

# Move file between B2 folders (server-side, zero bandwidth used)
rclone moveto b2:${B2_BUCKET}/old-folder/model.safetensors b2:${B2_BUCKET}/checkpoints/model.safetensors

# rclone web GUI - open port 5572 in Quickpod first, then visit pod_url:5572
rclone rcd --rc-web-gui --rc-no-auth --rc-addr :5572 --rc-serve &

── B2 CLI - DOWNLOAD ──────────────────────────────────────────────

# Download single file to current folder (pwd)
b2 file download b2://${B2_BUCKET}/checkpoints/model.safetensors ./model.safetensors

# Download single file to specific path
b2 file download b2://${B2_BUCKET}/checkpoints/model.safetensors /workspace/models/checkpoints/model.safetensors

# Download entire folder
b2 sync b2://${B2_BUCKET}/checkpoints/ /workspace/models/checkpoints/

── B2 CLI - UPLOAD ────────────────────────────────────────────────

# Upload single file from current folder (pwd)
b2 file upload ${B2_BUCKET} ./model.safetensors checkpoints/model.safetensors

# Upload single file from specific path
b2 file upload ${B2_BUCKET} /workspace/models/checkpoints/model.safetensors checkpoints/model.safetensors

# Upload entire folder
b2 sync /workspace/output/ b2://${B2_BUCKET}/output/

── B2 CLI - MANAGE FILES ──────────────────────────────────────────

# List files in bucket folder
b2 ls b2://${B2_BUCKET}/checkpoints/

# List with file sizes
b2 ls --long b2://${B2_BUCKET}/checkpoints/

# Server-side move (copy to new location then delete original - no bandwidth used)
b2 ls --long b2://${B2_BUCKET}/old-folder/           # note the fileID
b2 file copy-by-id <fileID> ${B2_BUCKET} checkpoints/model.safetensors
b2 file delete-file-version ${B2_BUCKET} old-folder/model.safetensors <fileID>

── RESTART ComfyUI ────────────────────────────────────────────────
tini is PID 1 - safe to kill ComfyUI without killing the pod.

pkill -f "main.py"
cd /root/ComfyUI && python3 main.py ${CLI_ARGS} &

── FOLDER MAP ─────────────────────────────────────────────────────
/workspace/
├── models/
│   ├── checkpoints/        b2:BUCKET/checkpoints/
│   ├── loras/              b2:BUCKET/loras/
│   ├── vae/                b2:BUCKET/vae/
│   ├── clip/               b2:BUCKET/clip/
│   ├── diffusion_models/   b2:BUCKET/diffusion_models/
│   ├── upscale_models/     b2:BUCKET/upscale_models/
│   ├── controlnet/         b2:BUCKET/controlnet/
│   └── embeddings/         b2:BUCKET/embeddings/
├── input/                  b2:BUCKET/input/
├── output/                 b2:BUCKET/output/
├── workflows/              b2:BUCKET/workflows/
├── pre-start.sh            optional: runs before ComfyUI each session
└── README.txt              this file

########################################
READMEEOF
echo "[INFO] README.txt written to /workspace/README.txt"

# ── Copy ComfyUI from image bundle ────────────────────────────────────────────
echo "[INFO] Copying ComfyUI from image bundle..."
mkdir -p "$COMFY_DIR"
cp --archive "/default-comfyui-bundle/ComfyUI/." "$COMFY_DIR/"
echo "[INFO] ComfyUI ready at $COMFY_DIR"

# ── Symlink /workspace into ComfyUI ──────────────────────────────────────────
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
    ["input"]="/workspace/input"
    ["output"]="/workspace/output"
    ["user/default/workflows"]="/workspace/workflows"
)

for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET="${SYMLINKS[$INTERNAL_PATH]}"
    LINK="$COMFY_DIR/$INTERNAL_PATH"
    mkdir -p "$(dirname "$LINK")"
    [ -d "$LINK" ] && [ ! -L "$LINK" ] && rm -rf "$LINK"
    ln -sf "$TARGET" "$LINK"
    echo "[INFO] Linked: $LINK -> $TARGET"
done

# ── Update ComfyUI-Manager (already in bundle, pull latest) ──────────────────
echo "[INFO] Updating ComfyUI-Manager..."
cd "$COMFY_DIR/custom_nodes/ComfyUI-Manager" && git pull || echo "[WARN] Manager update failed"

# ── Install additional custom nodes ──────────────────────────────────────────
echo "[INFO] Running install_nodes.sh..."
bash /app/install_nodes.sh

# ── Optional: per-session pre-start script ────────────────────────────────────
if [ -f "/workspace/pre-start.sh" ]; then
    echo "[INFO] Running /workspace/pre-start.sh..."
    chmod +x /workspace/pre-start.sh
    source /workspace/pre-start.sh
fi

# ── Launch ComfyUI ────────────────────────────────────────────────────────────
echo "########################################"
echo "  Launching ComfyUI..."
echo "  CLI_ARGS: ${CLI_ARGS}"
echo "########################################"

cd "$COMFY_DIR"
exec python3 main.py ${CLI_ARGS}
