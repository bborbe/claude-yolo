#!/bin/bash
set -euo pipefail

# Firewall + proxy
if [ "${DEBUG:-0}" = "1" ]; then
    sudo /usr/local/bin/init-firewall.sh
else
    sudo /usr/local/bin/init-firewall.sh > /dev/null 2>&1
fi

# Configure proxy for all HTTP(S) traffic
export HTTP_PROXY=http://127.0.0.1:8888
export HTTPS_PROXY=http://127.0.0.1:8888
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888
git config --global http.proxy http://127.0.0.1:8888
git config --global https.proxy http://127.0.0.1:8888

# Read prompt from file if specified
if [ -n "${YOLO_PROMPT_FILE:-}" ] && [ -f "${YOLO_PROMPT_FILE}" ]; then
    YOLO_PROMPT=$(cat "${YOLO_PROMPT_FILE}")
fi

# Check for prompt
if [ -n "${YOLO_PROMPT:-}" ]; then
    echo "Starting headless session..."
    exec claude -p "${YOLO_PROMPT}" --dangerously-skip-permissions --model claude-sonnet-4-5 --output-format stream-json --verbose \
        | python3 /usr/local/bin/stream-formatter.py
else
    # Interactive mode
    echo "Starting interactive session..."
    exec claude --dangerously-skip-permissions --model claude-sonnet-4-5
fi
