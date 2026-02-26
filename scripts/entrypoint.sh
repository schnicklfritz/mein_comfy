#!/bin/bash
set -e

COMFY_DIR="/root/ComfyUI"
PERSISTENT_ROOT="/workspace/ComfyUI_Data"

echo "🛰️ Initializing Pod Storage..."

# 1. Create Persistent Folders & Permissions
mkdir -p "$PERSISTENT_ROOT/checkpoints"
mkdir -p "$PERSISTENT_ROOT/rclone-config"
chmod -R 777 "$PERSISTENT_ROOT"

# 2. CREATE THE USER SCRIPT IN /WORKSPACE
# This is for manual use: cd /workspace && ./start_rclone.sh
cat << 'EOF' > /workspace/start_rclone.sh
#!/bin/bash
echo "🚀 Starting Rclone GUI on port 5572..."
echo "🔑 Login: admin / password123"
rclone rcd --rc-web-gui \
    --rc-addr :5572 \
    --rc-user admin \
    --rc-pass password123 \
    --rc-web-gui-no-open-browser \
    --config /workspace/ComfyUI_Data/rclone-config/rclone.conf
EOF
chmod +x /workspace/start_rclone.sh

# 3. ComfyUI Self-Healing
# Note: Base image includes ComfyUI-Manager per your request
if [ ! -f "$COMFY_DIR/main.py" ]; then
    echo "⬇️ Downloading ComfyUI..."
    git clone https://github.com "$COMFY_DIR"
fi

# 4. Smart Linking Loop
declare -A SYMLINKS=(
    ["models/checkpoints"]="checkpoints"
    ["models/loras"]="loras"
    ["input"]="input"
    ["output"]="output"
)

for INT in "${!SYMLINKS[@]}"; do
    EXT="$PERSISTENT_ROOT/${SYMLINKS[$INT]}"
    mkdir -p "$EXT"
    
    # Move default files to persistent storage if folder exists and isn't a link
    if [ -d "$COMFY_DIR/$INT" ] && [ ! -L "$COMFY_DIR/$INT" ]; then
        echo "📦 Moving files from $INT to persistent storage..."
        cp -rn "$COMFY_DIR/$INT"/* "$EXT/" 2>/dev/null || true
        rm -rf "$COMFY_DIR/$INT"
    fi
    
    # Create the symlink
    ln -sfn "$EXT" "$COMFY_DIR/$INT"
done

# 5. Launch ComfyUI
echo "✅ Setup Complete. Launching ComfyUI..."
cd "$COMFY_DIR"
exec python3 main.py --listen 0.0.0.0 --port 8188 $CLI_ARGS
