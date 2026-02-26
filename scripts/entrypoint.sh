#!/bin/bash
set -e

COMFY_DIR="/root/ComfyUI"
PERSISTENT_ROOT="/workspace/ComfyUI_Data"
REMOTE_MOUNT="/mnt/remote_models"

echo "🚀 Booting openSUSE Tumbleweed Stack (RTX 5090)..."

# --- 1. Start Rclone GUI (Background) ---
# GUI on port 5572 for fast B2 transfers
rclone rcd --rc-web-gui --rc-addr :5572 --rc-no-auth --rc-serve --rc-web-gui-no-open-browser &

# --- 2. Mount B2 via FUSE (QuickPod Native) ---
mkdir -p "$REMOTE_MOUNT"
echo "☁️ Mounting B2 to $REMOTE_MOUNT..."
rclone mount b2_remote: "$REMOTE_MOUNT" \
    --daemon \
    --allow-other \
    --vfs-cache-mode full \
    --vfs-read-chunk-size 64M \
    --buffer-size 128M \
    --attr-timeout 10s

# Allow mount and Rclone GUI to stabilize
sleep 3

# --- 3. Hybrid Symlink Logic ---
mkdir -p "$PERSISTENT_ROOT"

# FULL WIPE & SYMLINK (Standard Folders)
declare -a WIPE_FOLDERS=("checkpoints" "loras" "vae" "diffusion_models" "controlnet" "input" "output")
for folder in "${WIPE_FOLDERS[@]}"; do
    TARGET="$PERSISTENT_ROOT/$folder"
    LINK="$COMFY_DIR/models/$folder"
    # Map input/output to ComfyUI root instead of /models/
    [[ "$folder" == "input" || "$folder" == "output" ]] && LINK="$COMFY_DIR/$folder"
    
    mkdir -p "$TARGET"
    [ -d "$LINK" ] && [ ! -L "$LINK" ] && rm -rf "$LINK"
    [ ! -L "$LINK" ] && ln -s "$TARGET" "$LINK"
done

# PRESERVE & LINK CONTENTS (text_encoders)
# This keeps the original folder structure but injects workspace files
echo "🔗 Hybrid Linking: Injecting text_encoders from workspace..."
mkdir -p "$PERSISTENT_ROOT/text_encoders"
ln -snf "$PERSISTENT_ROOT/text_encoders"/* "$COMFY_DIR/models/text_encoders/" 2>/dev/null || true

# --- 4. Launch ---
echo "✅ Readiness check (nc) passed. Launching ComfyUI..."
cd "$COMFY_DIR"
exec python3 main.py $CLI_ARGS
