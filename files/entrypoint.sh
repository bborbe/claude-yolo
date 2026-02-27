#!/bin/bash
set -euo pipefail

# Firewall
sudo /usr/local/bin/init-firewall.sh

# Check for prompt
if [ -n "${YOLO_PROMPT:-}" ]; then
    # Use script to create pseudo-TTY for Claude output
    echo "Starting headless session..."
    echo "${YOLO_PROMPT}" | claude --dangerously-skip-permissions --model claude-sonnet-4-5
    exit "${PIPESTATUS[0]}"
else
    # Interactive mode
    echo "Starting interactive session..."
    exec claude --dangerously-skip-permissions --model claude-sonnet-4-5
fi
