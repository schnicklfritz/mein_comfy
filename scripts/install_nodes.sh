#!/bin/bash
set -e

# Nodes baked into base image /ComfyUI/custom_nodes/
# Ashley's sync copies this to /workspace/ComfyUI/custom_nodes/ on first start

NODES_DIR="/ComfyUI/custom_nodes"
VENV_PIP="/ComfyUI/venv/bin/pip"

echo "########################################"
echo "  install_nodes.sh - build time"
echo "########################################"

git clone --depth=1 \
    https://github.com/DanielPFlorian/ComfyUI-WorkflowGenerator \
    "$NODES_DIR/ComfyUI-WorkflowGenerator"
"$VENV_PIP" install -q -r "$NODES_DIR/ComfyUI-WorkflowGenerator/requirements.txt" \
    || echo "[WARN] ComfyUI-WorkflowGenerator deps failed"

echo "########################################"
echo "  Node installation complete."
echo "########################################"
