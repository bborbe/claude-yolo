#!/bin/bash
set -euo pipefail

# Usage: yolo-run.sh [path] ["prompt"]
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

# Check for existing YOLO execution in this directory
LOCK_FILE="$GIT_ROOT/.yolo-lock"
if [ -f "$LOCK_FILE" ]; then
    echo "ERROR: YOLO already running in $GIT_ROOT"
    echo "Lock file: $LOCK_FILE"
    echo "If no YOLO is running, remove lock file: rm $LOCK_FILE"
    exit 1
fi

# Create lock file - will be removed when container exits
touch "$LOCK_FILE"

echo "Starting claude-yolo container..."

# Run container in background with full interactivity
CONTAINER_ID=$(docker run -dit --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    -e YOLO_PROMPT="$PROMPT" \
    -v "$GIT_ROOT:/workspace" \
    -v "$HOME/.claude-yolo:/home/node/.claude" \
    -v "$HOME/go/pkg:/home/node/go/pkg" \
    docker.io/bborbe/claude-yolo:latest)

echo "Container ID: $CONTAINER_ID"
echo ""
echo "To attach and interact:  docker attach $CONTAINER_ID"
echo "To detach while inside:  Ctrl+P Ctrl+Q"
echo "To view logs:            docker logs -f $CONTAINER_ID"
echo ""

# Kill container on script exit/interrupt and remove lock file
trap 'docker kill '"$CONTAINER_ID"' 2>/dev/null; rm -f '"'$LOCK_FILE'" EXIT INT TERM

# Follow logs and wait for completion
docker logs -f "$CONTAINER_ID"
docker wait "$CONTAINER_ID" >/dev/null 2>&1
