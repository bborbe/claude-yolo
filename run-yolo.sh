#!/bin/bash
set -euo pipefail

# Usage: run-yolo.sh [path]
# If no path given, use current directory

TARGET_DIR="${1:-.}"

# Find git root
if ! GIT_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null); then
    echo "ERROR: Not in a git repository: $TARGET_DIR"
    exit 1
fi

echo "Git root detected: $GIT_ROOT"
echo "Starting claude-yolo container..."

# Run container with git root mounted (auto-generated name for parallel instances)
docker run -it --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    -v "$GIT_ROOT:/workspace" \
    -v ~/.claude-yolo:/home/node/.claude:rw \
    -v "$HOME/go/pkg:/home/node/go/pkg" \
    claude-yolo
