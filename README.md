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

### Interactive Mode (No Prompt)

Start an interactive Claude Code session in auto-approve mode:

```bash
# From current directory
./run-yolo.sh

# From specific project
./run-yolo.sh ~/Documents/workspaces/my-app

# From subdirectory (auto-detects git root)
cd src/api/client
./run-yolo.sh
```

Inside container:
- Work at git root (`/workspace`)
- Claude Code with `--dangerously-skip-permissions`
- Network restricted to allowed domains only
- Go module cache mounted for speed

### One-Shot Mode (With Prompt)

Execute a prompt and exit automatically:

```bash
# Inline prompt
./run-yolo.sh "implement OAuth2 login with JWT tokens"

# Prompt for specific project
./run-yolo.sh ~/Documents/workspaces/my-app "add user authentication"

# Multi-line prompt
./run-yolo.sh "$(cat <<'EOF'
Implement the following feature:
- Add REST API endpoint /api/users
- Add validation middleware
- Write tests with >80% coverage
EOF
)"

# From file
./run-yolo.sh "$(cat task-spec.md)"
```

**Use cases:**
- Automated task execution from specs
- CI/CD pipeline integration
- Batch processing multiple prompts
- Dark Factory pattern (spec → implementation)

### Helper Script

**`run-yolo.sh [path] ["prompt"]`**

**Arguments:**
- `path` (optional): Project directory or subdirectory (defaults to CWD)
- `prompt` (optional): Prompt to execute in one-shot mode

**How it works:**
1. Auto-detects git root from given path
2. Mounts git root as `/workspace`
3. Passes Go module cache for faster builds
4. If prompt given → one-shot mode (execute and exit)
5. If no prompt → interactive mode (standard session)

**Examples:**

```bash
# Interactive mode
./run-yolo.sh                                    # Current project
./run-yolo.sh ~/Documents/workspaces/my-app     # Specific project

# One-shot mode
./run-yolo.sh "add logging middleware"                              # Current project
./run-yolo.sh ~/Documents/workspaces/my-app "refactor auth module"  # Specific project

# From task file
TASK=$(cat ~/Documents/Obsidian/Personal/24\ Tasks/Build\ Feature.md)
./run-yolo.sh ~/Documents/workspaces/my-app "$TASK"
```

### Manual Docker Run

For advanced usage:

```bash
docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -e "YOLO_PROMPT=your prompt here" \
  -v ~/Documents/workspaces/my-app:/workspace \
  -v ~/.claude-yolo:/home/node/.claude \
  -v ~/go/pkg:/home/node/go/pkg \
  claude-yolo
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
