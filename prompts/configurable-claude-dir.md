---
status: draft
---

<summary>
- The Claude config directory mounted into the container is configurable via CLAUDE_YOLO_DIR env var
- Defaults to ~/.claude-yolo if not set (no breaking change)
- Users can point to a different config directory per project or machine
- Single-prompt execution mode also respects the new variable
- Usage comments in both scripts document the new environment variable
</summary>

<objective>
Make the host-side Claude config directory (`~/.claude-yolo`) configurable via the `CLAUDE_YOLO_DIR` environment variable. This allows different projects or machines to use different config directories (different docs, different settings) without changing scripts.
</objective>

<context>
Read CLAUDE.md for project conventions.

Key files to read before making changes:
- `scripts/yolo-run.sh` — host-side script that runs the container; hardcodes `$HOME/.claude-yolo` in the `docker run` volume mount
- `scripts/yolo-prompt.sh` — host-side script for single prompt execution; delegates to yolo-run.sh (no own volume mount)
- `Dockerfile` — container build; `CLAUDE_CONFIG_DIR=/home/node/.claude` is the container-side path (unchanged)
</context>

<requirements>
### 1. Update `scripts/yolo-run.sh`

Replace the hardcoded path with a configurable variable with default:

```bash
CLAUDE_YOLO_DIR="${CLAUDE_YOLO_DIR:-$HOME/.claude-yolo}"
```

Add this near the top of the script, after `set -euo pipefail`.

Update the docker run volume mount from:
```bash
-v "$HOME/.claude-yolo:/home/node/.claude" \
```
to:
```bash
-v "$CLAUDE_YOLO_DIR:/home/node/.claude" \
```

### 2. Update usage comments in both scripts

In `scripts/yolo-run.sh`, add after the existing usage comment:

```bash
# Environment:
#   CLAUDE_YOLO_DIR  Path to Claude config directory (default: ~/.claude-yolo)
```

In `scripts/yolo-prompt.sh`, add the same environment comment after the existing usage block. yolo-prompt.sh delegates to yolo-run.sh so no volume mount change is needed there.

### 3. Update `CHANGELOG.md`

Add a new `## Unreleased` section above the first version entry (`## v0.4.3`):

```
- feat: Make Claude config directory configurable via CLAUDE_YOLO_DIR env var (defaults to ~/.claude-yolo)
```
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git
- Default MUST be `$HOME/.claude-yolo` — no breaking change for existing users
- The container-side path `/home/node/.claude` is unchanged — only the host-side source path is configurable
- Do NOT modify the Dockerfile — this is a host-side script change only
</constraints>

<verification>
```bash
make precommit
```
Must exit 0 (shellcheck passes on both scripts).
</verification>
