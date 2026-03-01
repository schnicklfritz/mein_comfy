#!/bin/bash
# /app/install_nodes.sh
# Custom node installer for mein_comfy
# Runs every pod start (pod is ephemeral - nodes must reinstall)
# Add nodes below using install_node function

set -e

COMFY_DIR="/root/ComfyUI"
NODES_DIR="$COMFY_DIR/custom_nodes"

install_node() {
    local repo="$1"
    local name
    name=$(basename "$repo" .git)

    echo "[NODE] Installing: $name"
    git clone --depth=1 "$repo" "$NODES_DIR/$name"

    if [ -f "$NODES_DIR/$name/requirements.txt" ]; then
        echo "[NODE] Installing requirements for $name..."
        pip install \
            -c /builder-scripts/constraints.txt \
            -r "$NODES_DIR/$name/requirements.txt"
    fi
    echo "[NODE] Done: $name"
}

echo "########################################"
echo "  Installing custom nodes..."
echo "########################################"

# ── Add nodes here ────────────────────────────────────────────────────────────
# install_node "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
# install_node "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
# install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
# install_node "https://github.com/rgthree/rgthree-comfy"
# install_node "https://github.com/WASasquatch/was-node-suite-comfyui"

echo "########################################"
echo "  Node installation complete."
echo "########################################"
