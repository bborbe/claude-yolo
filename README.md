# claude-yolo

Isolated Claude Code execution with prompt-based task handoffs. Run coding tasks in Docker with `--dangerous` mode while keeping your laptop supervised for critical operations.

## What This Is

A workflow separator for Claude Code:
- **Laptop (supervised)**: Planning, kubectl, git operations, deployments
- **Docker (--dangerous)**: Isolated coding with minimal permission prompts
- **Handoff mechanism**: `/create-prompt` → container execution → review/merge

## Installation

### 1. Install the plugin

```bash
# Add local marketplace
claude plugin marketplace add ~/path/to/claude-yolo

# Or from GitHub (once published)
claude plugin marketplace add bborbe/claude-yolo

# Install plugin (makes /create-prompt and /run-prompt available)
claude plugin install claude-yolo
```

### 2. Build the Docker image

```bash
make build
```

## Usage

### Workflow

```bash
# 1. Plan on laptop (from anywhere, e.g., Obsidian vault)
claude
> /create-prompt "add retry logic to notification service"
# → auto-discovers project: trading/core/signal/notification
# → saves to ~/Documents/workspaces/trading/prompts/001-add-retry.md

# 2. Execute in container (isolated, low-friction)
docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v ~/Documents/workspaces/trading:/workspace \
  -v ~/.claude.json:/home/node/.claude.json:ro \
  claude-yolo

# Inside container (CWD = git root):
/run-prompt 001
# → finds ./prompts/001-add-retry.md
# → implements, tests, commits to feature branch

# 3. Review and deploy on laptop
cd ~/Documents/workspaces/trading
git diff feature-branch
gh pr create
```

### Commands

**`/create-prompt <task description>`**
- Discovers target project from task description
- Finds git root automatically
- Saves to `{git_root}/prompts/NNN-name.md`
- Prompts are version-controlled with the project

**`/run-prompt <number|name>`**
- Searches `./prompts/` (CWD) first (works in Docker)
- Falls back to workspace scan if not found
- Executes prompt in fresh sub-task context
- Archives to `{git_root}/prompts/completed/` when done

## Features

### Network Firewall

Container runs with restricted network access via iptables:
- ✅ Allowed: GitHub, npm, Anthropic API, Go proxies
- ❌ Blocked: Everything else (example.com fails)
- Requires `--cap-add=NET_ADMIN --cap-add=NET_RAW`

### Git-Root Awareness

Prompts live at the git repository root:
```
trading/
├── prompts/
│   ├── 001-add-retry.md
│   ├── 002-fix-bug.md
│   └── completed/
├── core/signal/notification/  ← actual changes
└── ...
```

One prompt queue per repo. No global state.

### Docker Isolation

Container has:
- ✅ Read/write to mounted workspace
- ✅ Git operations within workspace
- ❌ No kubectl contexts
- ❌ No access to other repos
- ❌ No SSH keys (unless explicitly mounted)

## Configuration

Edit `Makefile` to customize:
- Workspace mount path
- Claude config location
- Model selection
- Network restrictions (in `init-firewall.sh`)

## Project Structure

```
claude-yolo/
├── .claude-plugin/         # Plugin manifests
│   ├── marketplace.json
│   └── plugin.json
├── commands/               # Claude Code slash commands
│   ├── create-prompt.md
│   └── run-prompt.md
├── Dockerfile             # Container definition
├── entrypoint.sh          # Container init
├── init-firewall.sh       # Network restrictions
└── Makefile              # Build/run helpers
```

## License

BSD-2-Clause
