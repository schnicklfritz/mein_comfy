#!/bin/bash
set -e

NODES_DIR="/opt/comfyui-staging/custom_nodes"
VENV_PIP="/opt/comfyui-staging/venv/bin/pip"

echo "########################################"
echo "  install_nodes.sh - build time"
echo "########################################"

# ── ComfyUI-WorkflowGenerator ─────────────────────────────────────────────────
git clone --depth=1 \
    https://github.com/DanielPFlorian/ComfyUI-WorkflowGenerator \
    "$NODES_DIR/ComfyUI-WorkflowGenerator"
"$VENV_PIP" install -q -r "$NODES_DIR/ComfyUI-WorkflowGenerator/requirements.txt" \
    || echo "[WARN] ComfyUI-WorkflowGenerator deps failed"

# ── joenorton/comfyui-mcp-server ──────────────────────────────────────────────
# Streamable-HTTP MCP server for ComfyUI — Open WebUI connects natively
# Runs as supervisord service on mein_comfy pod at :9000/mcp
git clone --depth=1 \
    https://github.com/joenorton/comfyui-mcp-server \
    /opt/comfyui-mcp-server
"$VENV_PIP" install -q requests websockets mcp \
    || echo "[WARN] comfyui-mcp-server deps failed"

echo "########################################"
echo "  Node installation complete."
echo "########################################"
