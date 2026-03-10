#!/bin/bash
set -euo pipefail

# Firewall + proxy
if [ "${DEBUG:-0}" = "1" ]; then
    sudo /usr/local/bin/init-firewall.sh
else
    sudo /usr/local/bin/init-firewall.sh > /dev/null 2>&1
fi

# Merge custom gitconfig if mounted (must be before git config --global)
if [ -f /home/node/.gitconfig-extra ]; then
    cp /home/node/.gitconfig-extra /home/node/.gitconfig
fi

# Configure proxy for all HTTP(S) traffic
export HTTP_PROXY=http://127.0.0.1:8888
export HTTPS_PROXY=http://127.0.0.1:8888
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888
git config --global http.proxy http://127.0.0.1:8888
git config --global https.proxy http://127.0.0.1:8888
git config --global --add safe.directory /workspace

# Read prompt from file if specified
if [ -n "${YOLO_PROMPT_FILE:-}" ] && [ -f "${YOLO_PROMPT_FILE}" ]; then
    YOLO_PROMPT=$(cat "${YOLO_PROMPT_FILE}")
fi

# Model selection (default: sonnet, auto-resolves to latest version)
MODEL="${YOLO_MODEL:-sonnet}"

# Output format: "print" for raw text, default uses stream-json + formatter
OUTPUT="${YOLO_OUTPUT:-stream}"

# Check for prompt
if [ -n "${YOLO_PROMPT:-}" ]; then
    echo "Starting headless session..."
    if [ "$OUTPUT" = "print" ]; then
        exec claude --print -p "${YOLO_PROMPT}" --dangerously-skip-permissions --model "${MODEL}" --verbose
    else
        exec claude -p "${YOLO_PROMPT}" --dangerously-skip-permissions --model "${MODEL}" --output-format stream-json --verbose \
            | python3 /usr/local/bin/stream-formatter.py
    fi
else
    # Interactive mode
    echo "Starting interactive session..."
    exec claude --dangerously-skip-permissions --model "${MODEL}"
fi
