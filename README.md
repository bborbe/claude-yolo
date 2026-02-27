# claude-yolo

Isolated Claude Code execution with prompt-based task handoffs. Run coding tasks in Docker with `--dangerous` mode while keeping your laptop supervised for critical operations.

## What This Is

Isolated Docker environment for running Claude Code with restricted network access and proper isolation from production systems.

## Installation

### 1. Build the Docker image

```bash
make build
```

### 2. Set up `~/.claude-yolo` directory

YOLO uses a **separate** Claude Code config directory (`~/.claude-yolo`) isolated from your main `~/.claude` config. This keeps YOLO's auto-approve workflow separate from your normal Claude sessions.

```bash
# Create YOLO config directory
mkdir -p ~/.claude-yolo/commands

# Copy sample CLAUDE.md (workflow instructions)
cp examples/CLAUDE.md ~/.claude-yolo/

# Optional: Install slash commands from claude-yolo-plugin
# See: https://github.com/bborbe/claude-yolo-plugin
```

**What's in `~/.claude-yolo`?**

```
~/.claude-yolo/
├── CLAUDE.md           # Workflow instructions for YOLO
├── commands/           # Slash commands available in YOLO
│   └── run-prompt.md   # Execute prompts (from plugin)
└── memory/             # Optional: YOLO-specific memory
```

**Why separate from `~/.claude`?**
- Different workflow (auto-approve vs supervised)
- Different constraints (no attribution, specific git patterns)
- Isolation from your main Claude config
- Safe experimentation

**How it's mounted:**
```bash
-v ~/.claude-yolo:/home/node/.claude
```

Inside container, YOLO sees `~/.claude-yolo` as `/home/node/.claude` and reads `CLAUDE.md` automatically.

## Usage

### Recommended: Prompt-Based Workflow

The cleanest way to use YOLO is with structured prompts:

**1. Create prompt** (in management session):
```
/create-prompt Build CLI with list/get/set commands
```
Saves to: `{project}/prompts/001-description.md`

**2. Execute with YOLO**:
```bash
./yolo-prompt.sh ~/Documents/workspaces/my-app 001
```

**3. Press Enter** at prompt dialog (current limitation)

**4. YOLO executes** `/run-prompt 001` inside container:
- Finds prompt file
- Reads XML-structured content
- Implements autonomously
- Archives to `prompts/completed/`

**Benefits:**
- ✅ Clean separation: planning vs execution
- ✅ Prompts live in project repo
- ✅ Reusable slash command logic
- ✅ Automatic archiving
- ✅ No duplication

**Requirements:**
- Install [claude-yolo-plugin](https://github.com/bborbe/claude-yolo-plugin) for `/create-prompt` and `/run-prompt`
- Copy slash commands to `~/.claude-yolo/commands/`

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
├── run-yolo.sh            # Launch container (interactive or one-shot)
├── yolo-prompt.sh         # Execute prompts via /run-prompt
├── examples/
│   └── CLAUDE.md          # Sample workflow configuration
├── Makefile               # Build/run helpers
└── README.md
```

**User's YOLO setup:**
```
~/.claude-yolo/            # Isolated YOLO config (separate from ~/.claude)
├── CLAUDE.md              # Workflow instructions (copied from examples/)
├── commands/              # Slash commands for YOLO
│   └── run-prompt.md      # From claude-yolo-plugin
└── memory/                # Optional YOLO-specific memory
```

**Project workspace:**
```
my-app/
├── prompts/               # Executable prompts (created by /create-prompt)
│   ├── 001-feature.md
│   ├── 002-bugfix.md
│   └── completed/         # Archived after execution
└── ...                    # Your project files
```

## Related Projects

**Claude YOLO Plugin** - Slash commands for prompt-based workflow:
- Repository: https://github.com/bborbe/claude-yolo-plugin
- Commands: `/create-prompt`, `/run-prompt`
- Installation: Copy commands to `~/.claude-yolo/commands/`

**Attribution:**
- Slash commands inspired by [taches-cc-resources](https://github.com/glittercowboy/taches-cc-resources)
- Dark Factory pattern concept
- Prompt engineering best practices

## Architecture

**Management Session** (your laptop, safe):
- Create prompts with `/create-prompt`
- Review implementation results
- Commit acceptable changes

**YOLO Container** (Docker, isolated, auto-approve):
- Reads `~/.claude-yolo/CLAUDE.md` for workflow
- Executes prompts autonomously
- Runs tests, commits changes
- Restricted network access (firewall)

**Key Insight:** Isolation enables autonomy. Auto-approve mode is safe because the container can't access production systems.

## License

BSD-2-Clause
