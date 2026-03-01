#!/bin/bash
# /app/entrypoint.sh
# mein_comfy entrypoint for Quickpod (ephemeral pod)
# /workspace is mounted per-session but NOT persistent between pod destroys
# All persistence via Backblaze B2 (manual - see /workspace/README.txt)

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

# ── /workspace mount check ────────────────────────────────────────────────────
if ! mountpoint -q /workspace 2>/dev/null; then
    echo "[WARN] /workspace is NOT a mounted volume."
    echo "[WARN] Models pulled from B2 will not be accessible between sessions."
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
    /workspace/output

# ── Write README.txt ──────────────────────────────────────────────────────────
cat > /workspace/README.txt << 'READMEEOF'
########################################
mein_comfy - Storage Reference
########################################

NOTE: This pod is ephemeral. All data is lost on pod destroy.
      Use B2 to persist models and outputs between sessions.

── RCLONE (Recommended) ───────────────────────────────────────────
Config setup (run once per session if not in image):
  rclone config

# Download model from B2 to /workspace
rclone copy b2:BUCKET/checkpoints/model.safetensors /workspace/models/checkpoints/

# Upload file to B2
rclone copy /workspace/models/checkpoints/model.safetensors b2:BUCKET/checkpoints/

# Move file between B2 folders (server-side, no download/upload)
rclone moveto b2:BUCKET/old-folder/model.safetensors b2:BUCKET/new-folder/model.safetensors

# Sync entire output folder → B2
rclone sync /workspace/output b2:BUCKET/output --transfers 10 --progress

# List bucket contents
rclone ls  b2:BUCKET
rclone lsd b2:BUCKET    # folders only

── B2 CLI ─────────────────────────────────────────────────────────
# List files
b2 ls b2://BUCKET/checkpoints/

# Upload single file
b2 file upload BUCKET /workspace/models/checkpoints/model.safetensors checkpoints/model.safetensors

# Server-side move (copy + delete, no re-upload needed)
b2 ls --long b2://BUCKET/old-folder/   # get fileID from output
b2 file copy-by-id <fileID> BUCKET new-folder/model.safetensors
b2 file delete-file-version BUCKET old-folder/model.safetensors <fileID>

── ARIA2 (Fast Downloads from URLs) ───────────────────────────────
# Single file (16 parallel connections)
aria2c -x16 -s16 -d /workspace/models/checkpoints/ \
  "https://huggingface.co/.../model.safetensors"

# Custom filename
aria2c -x16 -s16 \
  -d /workspace/models/checkpoints/ \
  -o "my_model.safetensors" \
  "https://huggingface.co/.../resolve/main/model.safetensors"

# Batch download from list (one URL per line in urls.txt)
aria2c -x16 -s16 -i /workspace/urls.txt -d /workspace/models/checkpoints/

── FOLDER MAP ──────────────────────────────────────────────────────
/workspace/                            B2 recommended layout
├── models/
│   ├── checkpoints/    ← b2:BUCKET/checkpoints/
│   ├── loras/          ← b2:BUCKET/loras/
│   ├── vae/            ← b2:BUCKET/vae/
│   ├── clip/           ← b2:BUCKET/clip/
│   ├── diffusion_models/ ← b2:BUCKET/diffusion_models/
│   ├── upscale_models/ ← b2:BUCKET/upscale_models/
│   ├── controlnet/     ← b2:BUCKET/controlnet/
│   └── embeddings/     ← b2:BUCKET/embeddings/
├── input/              ← b2:BUCKET/input/
├── output/             ← b2:BUCKET/output/
└── README.txt          ← this file

── COMFYUI LOCATION ────────────────────────────────────────────────
ComfyUI runs from: /root/ComfyUI
Rebuilt from image every pod start (ephemeral).

########################################
READMEEOF
echo "[INFO] README.txt written to /workspace/README.txt"

# ── Copy ComfyUI from image bundle (always fresh - pod is ephemeral) ──────────
echo "[INFO] Copying ComfyUI from image bundle..."
mkdir -p "$COMFY_DIR"
cp --archive "/default-comfyui-bundle/ComfyUI/." "$COMFY_DIR/"
echo "[INFO] ComfyUI ready at $COMFY_DIR"

# ── Symlink /workspace folders into ComfyUI ───────────────────────────────────
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
)

for INTERNAL_PATH in "${!SYMLINKS[@]}"; do
    TARGET="${SYMLINKS[$INTERNAL_PATH]}"
    LINK="$COMFY_DIR/$INTERNAL_PATH"
    LINK_PARENT=$(dirname "$LINK")

    mkdir -p "$LINK_PARENT"

    # Replace real dir with symlink (fresh copy always has real dirs)
    if [ -d "$LINK" ] && [ ! -L "$LINK" ]; then
        rm -rf "$LINK"
    fi

    ln -sf "$TARGET" "$LINK"
    echo "[INFO] Linked: $LINK → $TARGET"
done

# ── Install custom nodes ──────────────────────────────────────────────────────
echo "[INFO] Running install_nodes.sh..."
bash /app/install_nodes.sh

# ── Optional: pre-start user script ──────────────────────────────────────────
if [ -f "/workspace/pre-start.sh" ]; then
    echo "[INFO] Running /workspace/pre-start.sh..."
    chmod +x /workspace/pre-start.sh
    source /workspace/pre-start.sh
fi

# ── Launch ComfyUI ────────────────────────────────────────────────────────────
echo "########################################"
echo "  ComfyUI launching on port 8188"
echo "  CLI_ARGS: ${CLI_ARGS:-<none>}"
echo "########################################"

cd "$COMFY_DIR"
exec python3 main.py --listen --port 8188 ${CLI_ARGS:-}
