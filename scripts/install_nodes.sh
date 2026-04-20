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
# ── ACE-Step-ComfyUI (official ACE-Step 1.5 nodes) ───────────────────────────
git clone --depth=1 \
    https://github.com/ace-step/ACE-Step-ComfyUI \
    "$NODES_DIR/ACE-Step-ComfyUI"
grep -vE "^(torch|torchvision|torchaudio)([ =><!]|$)" \
    "$NODES_DIR/ACE-Step-ComfyUI/requirements.txt" > /tmp/req_acestep.txt
"$VENV_PIP" install -q -r /tmp/req_acestep.txt \
    || echo "[WARN] ACE-Step-ComfyUI deps failed"

# ── TTS-Audio-Suite (RVC v2 + IndexTTS2 + F5-TTS + more) ─────────────────────
git clone --depth=1 \
    https://github.com/diodiogod/TTS-Audio-Suite \
    "$NODES_DIR/TTS-Audio-Suite"
grep -vE "^(torch|torchvision|torchaudio)([ =><!]|$)" \
    "$NODES_DIR/TTS-Audio-Suite/requirements.txt" > /tmp/req_tts.txt
"$VENV_PIP" install -q -r /tmp/req_tts.txt \
    || echo "[WARN] TTS-Audio-Suite deps failed"

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
