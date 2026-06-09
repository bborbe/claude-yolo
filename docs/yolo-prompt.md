# `scripts/yolo-prompt.sh` reference

Thin wrapper around `yolo-run.sh` that executes a specific prompt file from a project's `prompts/` directory via the `/run-prompt` slash command. Use it when you have prompt files already written by `/create-prompt` (or dark-factory) and want to fire one without typing the full path.

## Synopsis

```
yolo-prompt.sh <project-path> <prompt-number-or-name>
```

Both arguments are required.

| Arg | Meaning | Examples |
|---|---|---|
| `<project-path>` | Project directory (must be inside a git repo) | `~/Documents/workspaces/my-app`, `.` |
| `<prompt-number-or-name>` | Prompt identifier — number prefix OR name slug | `001`, `implement-cli`, `042` |

## How it works

1. Validates `<project-path>` is a git repo (`git rev-parse --show-toplevel`)
2. Builds the prompt string `/run-prompt <prompt-number-or-name>`
3. Delegates to `yolo-run.sh "<git-root>" "/run-prompt <id>"` (sibling script in the same directory)
4. The container executes the `/run-prompt` slash command (must be installed in `~/.claude-yolo/commands/`)
5. `/run-prompt` finds the matching file under `prompts/`, executes its content, and archives the prompt on success

This is one-shot mode: the container runs, completes the prompt, exits, and `--rm`s itself.

## Prompt file lookup

`/run-prompt` (the slash command, not this script) resolves the identifier against `<project>/prompts/`:

| Identifier | Match strategy |
|---|---|
| `001` (numeric) | Prefix-match: `prompts/001-*.md` |
| `implement-cli` (alphabetic) | Name-match: `prompts/*implement-cli*.md` |

On success, the prompt is moved to `prompts/completed/`. On failure, it stays in `prompts/` so you can fix and retry.

The slash command lives in the [claude-yolo-plugin](https://github.com/bborbe/claude-yolo-plugin) repo. If it isn't installed in `~/.claude-yolo/commands/`, `yolo-prompt.sh` will launch the container but the `/run-prompt` call will fail inside it.

## Required project layout

The target project should follow the prompt-based workflow:

```
<project>/
├── prompts/                 # inbox — created by /create-prompt
│   ├── 001-feature.md
│   ├── 002-bugfix.md
│   ├── completed/           # auto-archived after successful run
│   └── log/                 # execution logs
└── ...
```

If `prompts/` doesn't exist or contains no matching file, the slash command errors out cleanly.

## When to use this vs `yolo-run.sh`

| Need | Use |
|---|---|
| Run an already-written prompt from `prompts/` | `yolo-prompt.sh <proj> <id>` |
| Run an ad-hoc inline prompt | `yolo-run.sh <proj> "<inline prompt>"` |
| Interactive session, no specific prompt | `yolo-run.sh <proj>` |
| Run an approved spec end-to-end (dark-factory's autopilot) | `dark-factory daemon` from the project — invokes the same machinery automatically |

The script is a convenience layer over `yolo-run.sh`. Anything `yolo-prompt.sh` does, you could do with `yolo-run.sh <proj> "/run-prompt <id>"` directly — the script just removes the typing.

## Inherits from `yolo-run.sh`

All of these come from the underlying call:

- Environment passthrough (`ANTHROPIC_*`, `CLAUDE_YOLO_DIR`)
- Volume mounts (`/workspace`, `/home/node/.claude`)
- Lock file behavior (`.yolo-lock` in the project's git root)
- Firewall (`--cap-add=NET_ADMIN --cap-add=NET_RAW`)
- One-shot output formatter (`YOLO_OUTPUT=stream` default)
- Exit codes

See `docs/yolo-run.md` for the full reference.

## Examples

```bash
# By number prefix
./scripts/yolo-prompt.sh ~/Documents/workspaces/vault-cli 001

# By name slug
./scripts/yolo-prompt.sh ~/Documents/workspaces/vault-cli implement-cli

# Current directory (relative path)
./scripts/yolo-prompt.sh . 042
```

## Failure modes

| Error | Cause | Fix |
|---|---|---|
| `Usage: ...` with exit 1 | Wrong arg count | Pass exactly two args: path + prompt id |
| `ERROR: Not in a git repository: <path>` | `<project-path>` isn't (inside) a git repo | Pass a path under a `git init`ed tree |
| Container starts but `/run-prompt: command not found` | Slash command not installed in `~/.claude-yolo/commands/` | Install [claude-yolo-plugin](https://github.com/bborbe/claude-yolo-plugin) |
| Container exits with non-zero code after launching | `/run-prompt` failed (couldn't find the prompt, prompt's verification failed) | Check container logs; verify prompt exists under `<project>/prompts/` |
| Prompt runs but never moves to `prompts/completed/` | Prompt's verification step failed | Look at `prompts/log/<id>-*` for the verification output |

## Related

- `scripts/yolo-run.sh` — what this script delegates to (see `docs/yolo-run.md`)
- [claude-yolo-plugin](https://github.com/bborbe/claude-yolo-plugin) — provides `/run-prompt` and `/create-prompt`
- `README.md#prompt-execution-script` — high-level intent
- `docs/troubleshooting.md` — container failures
