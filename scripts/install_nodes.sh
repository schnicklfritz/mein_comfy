#!/bin/bash
# /app/install_nodes.sh
# Runs at IMAGE BUILD TIME (not pod start) via Dockerfile
# /workspace does not exist at build time - nodes are cloned to a staging dir
# and copied into place by pre_start.sh at runtime
# NOTE: Currently a no-op. Uncomment nodes to bake them into the image.

set -e

echo "########################################"
echo "  install_nodes.sh - build time"
echo "  (no nodes configured)"
echo "########################################"

# ── Add nodes here ────────────────────────────────────────────────────────────
# Nodes added here are baked into the image - no runtime download needed.
# To add a node, uncomment and add install lines. Example:
#
# apt-get install -y some-dep
# git clone --depth=1 https://github.com/author/SomeNode /opt/nodes-staging/SomeNode
# pip install -r /opt/nodes-staging/SomeNode/requirements.txt
#
# Then in pre_start.sh, copy from /opt/nodes-staging/ to /workspace/ComfyUI/custom_nodes/
# after the clone block.

echo "########################################"
echo "  Node installation complete."
echo "########################################"
