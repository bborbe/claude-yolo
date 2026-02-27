#!/bin/bash
set -euo pipefail

# Firewall
sudo /usr/local/bin/init-firewall.sh

# Check for prompt
if [ -n "${YOLO_PROMPT:-}" ]; then
    # One-shot mode: run prompt and exit
    echo "Running one-shot prompt..."
    exec claude --dangerously-skip-permissions --model claude-sonnet-4-5 -p "$YOLO_PROMPT"
else
    # Interactive mode
    echo "Starting interactive session..."
    exec claude --dangerously-skip-permissions --model claude-sonnet-4-5
fi
