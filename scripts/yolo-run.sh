#!/bin/bash
set -euo pipefail

# Usage: yolo-run.sh [--env-file <path>]... [path] ["prompt"]
# If no path given, use current directory
# If prompt given, run one-shot mode (execute prompt and exit)
# --env-file <path>  Pass an env file to docker run (repeatable). GNU --env-file=<path> form also accepted.
#                    Leading ~ or ~/ in the path is expanded to $HOME.
# Environment:
#   CLAUDE_YOLO_DIR  Path to Claude config directory (default: ~/.claude-yolo)
#                    If $CLAUDE_YOLO_DIR/env exists, it is auto-loaded into the container.

CLAUDE_YOLO_DIR="${CLAUDE_YOLO_DIR:-$HOME/.claude-yolo}"
CLAUDE_YOLO_IMAGE="${CLAUDE_YOLO_IMAGE:-docker.io/bborbe/claude-yolo}"
CLAUDE_YOLO_VERSION="${CLAUDE_YOLO_VERSION:-latest}"

TARGET_DIR="."
PROMPT=""
ENV_FILE_ARGS=()
POSITIONAL=()

# shellcheck disable=SC2088  # Intentional: literal tilde to strip prefix in the case branch below, not a HOME expansion
expand_tilde() {
    # Expand leading ~ or ~/ to $HOME (shell does NOT expand these in --env-file=~/x or in quoted strings)
    case "$1" in
        "~")     printf '%s\n' "$HOME" ;;
        "~/"*)   printf '%s\n' "$HOME/${1#\~/}" ;;
        *)       printf '%s\n' "$1" ;;
    esac
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --env-file)
            [[ $# -ge 2 ]] || { echo "ERROR: --env-file requires a path argument" >&2; exit 1; }
            envpath="$(expand_tilde "$2")"
            [[ -f "$envpath" ]] || { echo "ERROR: --env-file path does not exist: $envpath" >&2; exit 1; }
            ENV_FILE_ARGS+=(--env-file "$envpath")
            shift 2
            ;;
        --env-file=*)
            envpath="$(expand_tilde "${1#*=}")"
            [[ -f "$envpath" ]] || { echo "ERROR: --env-file path does not exist: $envpath" >&2; exit 1; }
            ENV_FILE_ARGS+=(--env-file "$envpath")
            shift
            ;;
        --)
            shift
            POSITIONAL+=("$@")
            break
            ;;
        -*)
            echo "ERROR: unknown option: $1" >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Replicate legacy single-arg / two-arg semantics on collected positionals
if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
    arg="${POSITIONAL[0]}"
    # Could be path OR prompt
    if [ -d "$arg" ] || [ -f "$arg" ] || (cd "$arg" && git rev-parse --show-toplevel) >/dev/null 2>&1; then
        TARGET_DIR="$arg"
    else
        PROMPT="$arg"
    fi
elif [[ ${#POSITIONAL[@]} -eq 2 ]]; then
    TARGET_DIR="${POSITIONAL[0]}"
    PROMPT="${POSITIONAL[1]}"
elif [[ ${#POSITIONAL[@]} -gt 2 ]]; then
    echo "ERROR: too many positional arguments (expected at most 2: [path] [\"prompt\"])" >&2
    exit 1
fi

# Find git root, fall back to TARGET_DIR if not a git repo
if GIT_ROOT=$(cd "$TARGET_DIR" && git rev-parse --show-toplevel 2>/dev/null); then
    echo "Git root detected: $GIT_ROOT"
else
    if ! GIT_ROOT=$(cd "$TARGET_DIR" 2>/dev/null && pwd); then
        echo "ERROR: target directory does not exist: $TARGET_DIR" >&2
        exit 1
    fi
    echo "No git repo — mounting directory directly: $GIT_ROOT"
fi

if [ -n "$PROMPT" ]; then
    echo "Mode: One-shot (execute prompt and exit)"
else
    echo "Mode: Interactive"
fi

# Check for existing YOLO execution in this directory
LOCK_FILE="$GIT_ROOT/.yolo-lock"
if [ -f "$LOCK_FILE" ]; then
    OLD_CONTAINER=$(cat "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$OLD_CONTAINER" ] && docker inspect "$OLD_CONTAINER" >/dev/null 2>&1; then
        echo "ERROR: YOLO already running in $GIT_ROOT"
        echo "Container: $OLD_CONTAINER"
        echo "To kill: docker kill $OLD_CONTAINER"
        exit 1
    fi
    echo "Removing stale lock file (container no longer running)"
    rm -f "$LOCK_FILE"
fi

DEFAULT_ENV_FILE="$CLAUDE_YOLO_DIR/env"
DEFAULT_ENV_ARGS=()
if [[ -f "$DEFAULT_ENV_FILE" ]]; then
    DEFAULT_ENV_ARGS=(--env-file "$DEFAULT_ENV_FILE")
fi

echo "Starting claude-yolo container ${CLAUDE_YOLO_IMAGE}:${CLAUDE_YOLO_VERSION}..."

# Run container in background with full interactivity
CONTAINER_ID=$(docker run -dit --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    --add-host=host.docker.internal:host-gateway \
    ${DEFAULT_ENV_ARGS[@]+"${DEFAULT_ENV_ARGS[@]}"} \
    ${ENV_FILE_ARGS[@]+"${ENV_FILE_ARGS[@]}"} \
    -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-}" \
    -e ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}" \
    -e ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-}" \
    -e DEBUG="${DEBUG:-}" \
    -e YOLO_PROMPT="$PROMPT" \
    -v "$GIT_ROOT:/workspace" \
    -v "$CLAUDE_YOLO_DIR:/home/node/.claude" \
    "${CLAUDE_YOLO_IMAGE}:${CLAUDE_YOLO_VERSION}")

# Write container ID to lock file
echo "$CONTAINER_ID" > "$LOCK_FILE"

echo "Container ID: $CONTAINER_ID"
echo ""
echo "To attach and interact:  docker attach $CONTAINER_ID"
echo "To detach while inside:  Ctrl+P Ctrl+Q"
echo "To view logs:            docker logs -f $CONTAINER_ID"
echo ""

# Kill container on script exit/interrupt and remove lock file
# shellcheck disable=SC2064  # Intentional: expand vars now, not at signal time
trap "docker kill $CONTAINER_ID 2>/dev/null || true; rm -f $LOCK_FILE" EXIT INT TERM

# Interactive: attach (can type), One-shot: follow logs
if [ -z "$PROMPT" ]; then
    docker attach "$CONTAINER_ID"
else
    docker logs -f "$CONTAINER_ID"
    docker wait "$CONTAINER_ID" >/dev/null 2>&1
fi
