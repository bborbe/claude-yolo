#!/bin/bash
set -euo pipefail

# Firewall
sudo /usr/local/bin/init-firewall.sh

# Create logs directory
mkdir -p /workspace/.logs

# Add .logs to .gitignore if not already there
if [ -f /workspace/.gitignore ]; then
    grep -q "^\.logs/$" /workspace/.gitignore || echo ".logs/" >> /workspace/.gitignore
else
    echo ".logs/" > /workspace/.gitignore
fi

# Check for prompt
if [ -n "${YOLO_PROMPT:-}" ]; then
    # One-shot mode: run prompt and exit with logging
    TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
    LOGFILE="/workspace/.logs/yolo-${TIMESTAMP}.log"

    echo "Running one-shot prompt..."
    echo "Logging to: .logs/yolo-${TIMESTAMP}.log"
    echo ""

    # Stream output to both terminal and log file
    claude --dangerously-skip-permissions --model claude-sonnet-4-5 -p "$YOLO_PROMPT" 2>&1 | tee "$LOGFILE"
    exit ${PIPESTATUS[0]}
else
    # Interactive mode
    echo "Starting interactive session..."
    exec claude --dangerously-skip-permissions --model claude-sonnet-4-5
fi
