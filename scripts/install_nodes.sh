#!/bin/bash
# /app/install_nodes.sh
# Runs at IMAGE BUILD TIME (not pod start) via Dockerfile
# Add custom nodes to bake into the image

set -e

COMFY_DIR="/workspace/ComfyUI"
NODES_DIR="$COMFY_DIR/custom_nodes"

install_node() {
    local repo="$1"
    local name
    name=$(basename "$repo" .git)

    echo "[NODE] Installing: $name"
    git clone --depth=1 "$repo" "$NODES_DIR/$name"

    if [ -f "$NODES_DIR/$name/requirements.txt" ]; then
        echo "[NODE] Installing requirements for $name..."
        pip install -r "$NODES_DIR/$name/requirements.txt"
    fi
    echo "[NODE] Done: $name"
}

echo "########################################"
echo "  Installing custom nodes..."
echo "########################################"

# ── Add nodes here ────────────────────────────────────────────────────────────
# install_node "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
# install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
# install_node "https://github.com/rgthree/rgthree-comfy"
# install_node "https://github.com/WASasquatch/was-node-suite-comfyui"
# install_node "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
# install_node "https://github.com/kijai/ComfyUI-KJNodes"

echo "########################################"
echo "  Node installation complete."
echo "########################################"
