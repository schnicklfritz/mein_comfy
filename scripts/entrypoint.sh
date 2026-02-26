#!/bin/bash
set -e

COMFY_DIR="/root/ComfyUI"
PERSISTENT_ROOT="/workspace/ComfyUI_Data"
REMOTE_MOUNT="/mnt/remote_models"

echo "🚀 Starting QuickPod-Optimized Mein_Comfy..."

# --- 1. Launch Rclone Web GUI (Background) ---
# Accessible at http://[pod-ip]:5572
echo "🌐 Starting Rclone Web GUI..."
rclone rcd --rc-web-gui --rc-addr :5572 --rc-no-auth --rc-serve --rc-web-gui-no-open-browser &

# --- 2. Mount Backblaze B2 (Background) ---
# Since QuickPod supports FUSE, we use mount for seamless access.
mkdir -p "$REMOTE_MOUNT"
echo "☁️ Mounting B2 to $REMOTE_MOUNT..."
rclone mount b2_remote: "$REMOTE_MOUNT" \
    --daemon \
    --allow-other \
    --vfs-cache-mode full \
    --vfs-read-chunk-size 64M \
    --buffer-size 128M

# --- 3. Hybrid Symlink Logic ---
mkdir -p "$PERSISTENT_ROOT"

# FOLDERS TO WIPE & SYMLINK (Clean workspace)
declare -a WIPE_FOLDERS=("checkpoints" "loras" "vae" "diffusion_models" "controlnet" "input" "output")
for folder in "${WIPE_FOLDERS[@]}"; do
    TARGET="$PERSISTENT_ROOT/$folder"
    LINK="$COMFY_DIR/models/$folder"
    [ "$folder" == "input" ] || [ "$folder" == "output" ] && LINK="$COMFY_DIR/$folder"
    
    mkdir -p "$TARGET"
    [ -d "$LINK" ] && [ ! -L "$LINK" ] && rm -rf "$LINK"
    [ ! -L "$LINK" ] && ln -s "$TARGET" "$LINK"
done

# FOLDER TO PRESERVE (text_encoders)
# Inject contents from workspace without deleting the base folder
echo "🔗 Hybrid Linking: Protecting text_encoders..."
mkdir -p "$PERSISTENT_ROOT/text_encoders"
ln -snf "$PERSISTENT_ROOT/text_encoders"/* "$COMFY_DIR/models/text_encoders/" 2>/dev/null || true

# --- 4. Launch ComfyUI ---
# Using the 5090 optimization flags
cd "$COMFY_DIR"
exec python3 main.py $CLI_ARGS
