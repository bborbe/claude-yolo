#!/bin/bash
set -euo pipefail

# Usage: yolo-prompt.sh <project-path> <prompt-number-or-name>
# Example: yolo-prompt.sh ~/Documents/workspaces/vault-cli 001
# Example: yolo-prompt.sh ~/Documents/workspaces/vault-cli implement-cli

if [ $# -ne 2 ]; then
    echo "Usage: $0 <project-path> <prompt-number-or-name>"
    echo "Example: $0 ~/Documents/workspaces/vault-cli 001"
    echo "Example: $0 ~/Documents/workspaces/vault-cli implement-cli"
    exit 1
fi

PROJECT_PATH="$1"
PROMPT_ID="$2"

# Find git root
if ! GIT_ROOT=$(git -C "$PROJECT_PATH" rev-parse --show-toplevel 2>/dev/null); then
    echo "ERROR: Not in a git repository: $PROJECT_PATH"
    exit 1
fi

echo "Project: $GIT_ROOT"
echo "Prompt: $PROMPT_ID"
echo ""
echo "Executing YOLO with /run-prompt..."
echo ""

# Pass /run-prompt command to YOLO
# YOLO container will execute the slash command, which handles:
# - Finding the prompt file
# - Reading prompt content
# - Executing the prompt
# - Archiving to prompts/completed/
PROMPT_CONTENT="/run-prompt $PROMPT_ID"

# Resolve script directory relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute YOLO
"$SCRIPT_DIR/run-yolo.sh" "$GIT_ROOT" "$PROMPT_CONTENT"
