# claude-yolo

Isolated Claude Code execution with prompt-based task handoffs. Run coding tasks in Docker with `--dangerous` mode while keeping your laptop supervised for critical operations.

## What This Is

Isolated Docker environment for running Claude Code with restricted network access and proper isolation from production systems.

## Installation

### Build the Docker image

```bash
make build
```

## Usage

### Usage

```bash
# Start container for a project
cd ~/Documents/workspaces/my-app
./path/to/run-yolo.sh

# Inside container:
# - Work at git root (/workspace)
# - Claude Code available with --dangerously-skip-permissions
# - Network restricted to allowed domains only
```

Or manually with docker:
```bash
docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v ~/Documents/workspaces/my-app:/workspace \
  -v ~/.claude.json:/home/node/.claude.json:ro \
  claude-yolo
```

### Helper Script

**`run-yolo.sh [path]`**
- Auto-detects git root from given path (or CWD)
- Mounts git root as `/workspace`
- Starts container at git root
- Passes through Go module cache for faster builds

```bash
# From project root
./path/to/run-yolo.sh

# From subdirectory
cd src/api/client
./path/to/run-yolo.sh

# Explicit path
./path/to/run-yolo.sh ~/Documents/workspaces/my-app
```

## Features

### Network Firewall

Container runs with restricted network access via iptables:
- ✅ Allowed: GitHub, npm, Anthropic API, Go proxies
- ❌ Blocked: Everything else (example.com fails)
- Requires `--cap-add=NET_ADMIN --cap-add=NET_RAW`

### Git-Root Mounting

Container always works from git root:
```
my-app/
├── src/
├── go.mod
└── ...  ← mounted as /workspace in container
```

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
├── Dockerfile             # Container definition
├── entrypoint.sh          # Container init
├── init-firewall.sh       # Network restrictions
├── run-yolo.sh            # Helper script
├── Makefile               # Build/run helpers
└── README.md
```

## License

BSD-2-Clause
