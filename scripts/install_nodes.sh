#!/bin/bash
set -e

echo "🔧 Installing Custom Nodes for mein_comfy..."

COMFY_DIR="/root/ComfyUI"
NODES_DIR="$COMFY_DIR/custom_nodes"

cd "$NODES_DIR"

# --- Core Speed Nodes ---
echo "📦 Installing rgthree-comfy..."
git clone https://github.com/rgthree/rgthree-comfy.git
pip install -r rgthree-comfy/requirements.txt

echo "📦 Installing ComfyUI-KJNodes..."
git clone https://github.com/kijai/ComfyUI-KJNodes.git
pip install -r ComfyUI-KJNodes/requirements.txt

# --- Optional: Video/Advanced Nodes ---
# Uncomment if you need these
# echo "📦 Installing ComfyUI-VideoHelperSuite..."
# git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
# pip install -r ComfyUI-VideoHelperSuite/requirements.txt

echo "✅ Node installation complete!"
echo "🔄 Restart ComfyUI to activate nodes (or use Manager's restart button)."
