#!/bin/bash
set -euo pipefail

# Usage: run-yolo.sh [path] ["prompt"]
# If no path given, use current directory
# If prompt given, run one-shot mode (execute prompt and exit)

TARGET_DIR="."
PROMPT=""

# Parse arguments
if [ $# -eq 1 ]; then
    # Could be path OR prompt
    if [ -d "$1" ] || [ -f "$1" ] || git -C "$1" rev-parse --show-toplevel >/dev/null 2>&1; then
        TARGET_DIR="$1"
    else
        PROMPT="$1"
    fi
elif [ $# -eq 2 ]; then
    TARGET_DIR="$1"
    PROMPT="$2"
fi

# Find git root
if ! GIT_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null); then
    echo "ERROR: Not in a git repository: $TARGET_DIR"
    exit 1
fi

echo "Git root detected: $GIT_ROOT"

if [ -n "$PROMPT" ]; then
    echo "Mode: One-shot (execute prompt and exit)"
else
    echo "Mode: Interactive"
fi

echo "Starting claude-yolo container..."

# Run container with git root mounted (auto-generated name for parallel instances)
docker run -it --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    -e YOLO_PROMPT="$PROMPT" \
    -v "$GIT_ROOT:/workspace" \
    -v "$HOME/.claude-yolo:/home/node/.claude" \
    -v "$HOME/go/pkg:/home/node/go/pkg" \
    claude-yolo
