#!/bin/bash
set -euo pipefail

# Remap node user to match workspace owner (instant via /etc/passwd edit)
TARGET_UID=$(stat -c '%u' /workspace)
TARGET_GID=$(stat -c '%g' /workspace)
if [ "$TARGET_UID" != "0" ] && [ "$(id -u node)" != "$TARGET_UID" ]; then
    sed -i "s/^node:x:[0-9]*:[0-9]*/node:x:${TARGET_UID}:${TARGET_GID}/" /etc/passwd
    sed -i "s/^node:x:[0-9]*/node:x:${TARGET_GID}/" /etc/group
    # Fix ownership of home dir and key writable dirs (non-recursive for speed)
    chown "$TARGET_UID:$TARGET_GID" /home/node /home/node/.local /home/node/.npm /home/node/.config /usr/local/share/npm-global 2>/dev/null || true
fi

# Helper to run commands as node user
run_as_node() {
    setpriv --reuid=node --regid=node --init-groups -- "$@"
}

# Firewall + proxy
if [ "${DEBUG:-0}" = "1" ]; then
    /usr/local/bin/init-firewall.sh
else
    /usr/local/bin/init-firewall.sh > /dev/null 2>&1
fi

# Merge custom gitconfig if mounted (must be before git config --global)
if [ -f /home/node/.gitconfig-extra ]; then
    run_as_node cp /home/node/.gitconfig-extra /home/node/.gitconfig
fi

# Configure proxy for all HTTP(S) traffic
export HTTP_PROXY=http://127.0.0.1:8888
export HTTPS_PROXY=http://127.0.0.1:8888
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888
run_as_node git config --global http.proxy http://127.0.0.1:8888
run_as_node git config --global https.proxy http://127.0.0.1:8888
run_as_node git config --global --add safe.directory /workspace

# Resolve prompt to a temp file (avoids shell quoting issues with special characters)
if [ -n "${YOLO_PROMPT_FILE:-}" ] && [ -f "${YOLO_PROMPT_FILE}" ]; then
    PROMPT_FILE="$YOLO_PROMPT_FILE"
elif [ -n "${YOLO_PROMPT:-}" ]; then
    PROMPT_FILE=$(mktemp /tmp/yolo-prompt.XXXXXX)
    printf '%s' "$YOLO_PROMPT" > "$PROMPT_FILE"
fi

# Model selection (default: sonnet, auto-resolves to latest version)
MODEL="${YOLO_MODEL:-sonnet}"

# Output format: "print" for raw text, default uses stream-json + formatter
OUTPUT="${YOLO_OUTPUT:-stream}"

# Check for prompt
if [ -n "${PROMPT_FILE:-}" ]; then
    echo "Starting headless session..."
    # No trap — exec replaces the shell, so EXIT trap would delete the file before claude reads it
    if [ "$OUTPUT" = "print" ]; then
        exec setpriv --reuid=node --regid=node --init-groups -- \
            claude --print -p --dangerously-skip-permissions \
            --model "$MODEL" --verbose < "$PROMPT_FILE"
    else
        # exec + pipe requires sh -c; pass MODEL and PROMPT_FILE as positional args to avoid quoting issues
        # shellcheck disable=SC2016
        exec setpriv --reuid=node --regid=node --init-groups -- \
            sh -c 'claude -p --dangerously-skip-permissions --model "$1" \
                   --output-format stream-json --verbose < "$2" \
                   | python3 /usr/local/bin/stream-formatter.py' \
            _ "$MODEL" "$PROMPT_FILE"
    fi
else
    # Interactive mode
    echo "Starting interactive session..."
    exec setpriv --reuid=node --regid=node --init-groups -- claude --dangerously-skip-permissions --model "${MODEL}"
fi
