#!/bin/bash
set -euo pipefail

# Firewall
sudo /usr/local/bin/init-firewall.sh

# Check for prompt
if [ -n "${YOLO_PROMPT:-}" ]; then
    echo "Starting headless session..."
    # Write prompt to temp file to avoid escaping issues in expect
    PROMPT_FILE=$(mktemp)
    echo "${YOLO_PROMPT}" > "$PROMPT_FILE"

    # Use expect to:
    # 1. Start claude
    # 2. Wait for prompt, send the task
    # 3. Wait for completion, send /exit
    expect -f - -- "$PROMPT_FILE" <<'EXPECT_SCRIPT'
        set timeout -1
        set prompt_file [lindex $argv 0]
        set fp [open $prompt_file r]
        set prompt_content [string trimright [read $fp]]
        close $fp

        spawn claude --dangerously-skip-permissions --model claude-sonnet-4-5
        expect "❯"
        send -- "$prompt_content\r"
        expect "Type /exit"
        send "/exit\r"
        expect eof
EXPECT_SCRIPT

    rm -f "$PROMPT_FILE"
else
    # Interactive mode
    echo "Starting interactive session..."
    exec claude --dangerously-skip-permissions --model claude-sonnet-4-5
fi
