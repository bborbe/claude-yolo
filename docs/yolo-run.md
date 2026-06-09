# `scripts/yolo-run.sh` reference

Launches the YOLO container with Claude Code inside. Wraps `docker run` with sensible defaults: git-root detection, lock-file management, env passthrough, firewall capabilities. Quick reference here; conceptual overview in `README.md#usage`.

## Synopsis

```
yolo-run.sh [path] ["prompt"]
```

| Args | Mode | Behavior |
|---|---|---|
| (none) | Interactive | Mount cwd's git root, attach to a session |
| `<path>` | Interactive | Mount `<path>`'s git root, attach |
| `"<prompt>"` (single arg that isn't a path) | One-shot | Mount cwd, run prompt, exit |
| `<path> "<prompt>"` | One-shot | Mount `<path>`'s git root, run prompt, exit |

Single-arg disambiguation: if the arg is an existing directory/file OR `git rev-parse --show-toplevel` succeeds inside it, it's treated as a path; otherwise as a prompt string.

## Environment variables

| Var | Effect | Default |
|---|---|---|
| `CLAUDE_YOLO_DIR` | Host path mounted at `/home/node/.claude` inside container — holds `CLAUDE.md`, slash commands, plugins | `~/.claude-yolo` |
| `ANTHROPIC_BASE_URL` | Forwarded to container — points Claude at an alternate Anthropic-compatible API (e.g. MiniMax) | unset (uses official Anthropic) |
| `ANTHROPIC_AUTH_TOKEN` | Forwarded to container — API auth | unset (Claude will prompt if needed) |
| `ANTHROPIC_MODEL` | Forwarded to container — overrides default model | unset (container default: sonnet) |

All four are forwarded via `-e VAR="${VAR:-}"` — safe under `set -u`; unset on host means unset in container.

## What gets mounted

| Host path | Container path | Mode |
|---|---|---|
| Detected git root of `<path>` (or cwd) | `/workspace` | RW |
| `$CLAUDE_YOLO_DIR` (default `~/.claude-yolo`) | `/home/node/.claude` | RW |

`/workspace` is what Claude sees as the project root. Anything outside the git root is invisible to the container.

## Lock file

`<git-root>/.yolo-lock` — contains the running container's ID.

| State | Behavior |
|---|---|
| Absent | Normal launch |
| Present + container alive | `ERROR: YOLO already running in <git-root>` → exit 1 (prevents accidental double-launch on the same workspace) |
| Present + container dead | Auto-removed, normal launch |

Cleanup happens automatically on EXIT/INT/TERM via trap. `kill -9`, host crash, or `docker kill` can orphan the file — see `docs/troubleshooting.md#yolo-lock-cleanup`.

## Docker invocation

The script runs:

```bash
docker run -dit --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    -e ANTHROPIC_BASE_URL="..." \
    -e ANTHROPIC_AUTH_TOKEN="..." \
    -e ANTHROPIC_MODEL="..." \
    -e YOLO_PROMPT="<prompt>" \
    -v "<git-root>:/workspace" \
    -v "$CLAUDE_YOLO_DIR:/home/node/.claude" \
    docker.io/bborbe/claude-yolo:latest
```

- `-d` detached, `-i` stdin open, `-t` TTY allocated, `--rm` clean up on exit
- `--cap-add=NET_ADMIN --cap-add=NET_RAW` — required for `init-firewall.sh` to set iptables rules (see `docs/network-firewall.md`)

## Modes (under the hood)

| Mode | Trigger | Container entrypoint behavior |
|---|---|---|
| Interactive | `YOLO_PROMPT` empty | `exec claude --dangerously-skip-permissions --model "$MODEL"` (stdin attached) |
| One-shot (default formatter) | `YOLO_PROMPT` set, `YOLO_OUTPUT` unset/`stream` | `claude -p --output-format stream-json --verbose < $PROMPT_FILE \| stream-formatter.py` |
| One-shot (raw print) | `YOLO_PROMPT` set, `YOLO_OUTPUT=print` | `claude --print -p --verbose < $PROMPT_FILE` |
| One-shot (raw JSON) | `YOLO_PROMPT` set, `YOLO_OUTPUT=json` | `claude -p --output-format stream-json --verbose < $PROMPT_FILE` |

`YOLO_OUTPUT` is read by the container entrypoint, not the host script. Set it via `-e YOLO_OUTPUT=...` on a raw `docker run`, or pre-set in `~/.claude-yolo/env` (see `README.md#configuration`) if env-passthrough is enabled.

## Interactive: attach + detach

After launch, the script `docker attach`es you to the container. Keys:

| Action | Keys |
|---|---|
| Detach (leave container running) | **Ctrl+P Ctrl+Q** |
| End session (kills container — `--rm` cleans up) | Inside Claude: `/exit`. Or `exit` at shell prompt. |
| ❌ Cancel current command | **Don't Ctrl+C** — it forwards SIGINT to the container PID 1 (kills the session). Use Claude's own cancellation. |

If you accidentally detach, reattach with `docker attach <container-id>` (the ID is printed on launch and stored in `.yolo-lock`).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Container exited cleanly (interactive `/exit` or one-shot prompt completed) |
| 1 | Pre-launch error (not in git repo, lock collision, docker unavailable) |
| `>1` | Forwarded from container — usually a non-zero `claude -p` exit (prompt failed) or firewall init failure |

## Examples

```bash
# Interactive, current project
./scripts/yolo-run.sh

# Interactive, specific project
./scripts/yolo-run.sh ~/Documents/workspaces/my-app

# One-shot inline prompt
./scripts/yolo-run.sh "add logging middleware"

# One-shot from file
./scripts/yolo-run.sh ~/Documents/workspaces/my-app "$(cat task-spec.md)"

# Alternative API provider (MiniMax)
ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic \
ANTHROPIC_AUTH_TOKEN=$MINIMAX_TOKEN \
ANTHROPIC_MODEL=MiniMax-M3-highspeed \
  ./scripts/yolo-run.sh ~/Documents/workspaces/my-app "fix the failing test"
```

## Related

- `scripts/yolo-prompt.sh` — convenience wrapper for `/run-prompt <id>` execution (see `docs/yolo-prompt.md`)
- `files/entrypoint.sh` — container-side initialization (firewall + claude launch)
- `docs/network-firewall.md` — what `--cap-add=NET_ADMIN` is for
- `docs/troubleshooting.md` — lock file orphans, attach issues, network failures
- `README.md#usage` — conceptual overview + prompt-based workflow
