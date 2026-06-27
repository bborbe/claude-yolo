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

### 3. Authenticate the YOLO Claude session

`~/.claude-yolo` needs its **own** Claude OAuth token — separate from your main `~/.claude` login. The token lives in `~/.claude-yolo/.credentials.json` (or `.claude.json` on older versions) and **expires periodically**, so plan to re-login when:

- `dark-factory` (or any wrapper using `~/.claude-yolo`) fails with `Claude OAuth token missing or expired in /Users/<you>/.claude-yolo`
- The healthcheck `claude` probe returns `stdout=""` despite the container starting cleanly
- You see `Not logged in · Please run /login` inside a YOLO interactive session

**Refresh the token** (one of two ways):

```bash
# (a) Inside an interactive YOLO container — recommended; closest to how dark-factory uses it
./scripts/yolo-run.sh
# in the Claude session, type:
/login
# follow the device-code flow in your browser; on success the container reports
# "Login successful" — exit, and ~/.claude-yolo/.credentials.json is updated

# (b) On the host with the YOLO config dir set explicitly
CLAUDE_CONFIG_DIR=~/.claude-yolo claude
# inside the session, run /login as above
```

Both paths write to the same file — the container path is preferred because it's exactly the environment dark-factory will use.

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
./scripts/yolo-prompt.sh ~/Documents/workspaces/my-app 001
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
./scripts/yolo-run.sh

# From specific project
./scripts/yolo-run.sh ~/Documents/workspaces/my-app

# From subdirectory (auto-detects git root)
cd src/api/client
./scripts/yolo-run.sh
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
./scripts/yolo-run.sh "implement OAuth2 login with JWT tokens"

# Prompt for specific project
./scripts/yolo-run.sh ~/Documents/workspaces/my-app "add user authentication"

# Multi-line prompt
./scripts/yolo-run.sh "$(cat <<'EOF'
Implement the following feature:
- Add REST API endpoint /api/users
- Add validation middleware
- Write tests with >80% coverage
EOF
)"

# From file
./scripts/yolo-run.sh "$(cat task-spec.md)"
```

**Use cases:**
- Automated task execution from specs
- CI/CD pipeline integration
- Batch processing multiple prompts
- Dark Factory pattern (spec → implementation)

### Helper Script

**`yolo-run.sh [path] ["prompt"]`**

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
./scripts/yolo-run.sh                                    # Current project
./scripts/yolo-run.sh ~/Documents/workspaces/my-app     # Specific project

# One-shot mode
./scripts/yolo-run.sh "add logging middleware"                              # Current project
./scripts/yolo-run.sh ~/Documents/workspaces/my-app "refactor auth module"  # Specific project

# From task file
TASK=$(cat ~/Documents/Obsidian/Personal/24\ Tasks/Build\ Feature.md)
./scripts/yolo-run.sh ~/Documents/workspaces/my-app "$TASK"
```

### Prompt Execution Script

**`yolo-prompt.sh <project-path> <prompt-number-or-name>`**

Executes a specific prompt from the project's `prompts/` directory via `/run-prompt`.

**Arguments:**
- `project-path` (required): Project directory
- `prompt-number-or-name` (required): Prompt number (e.g., `001`) or name (e.g., `implement-cli`)

**Examples:**
```bash
# By number
./scripts/yolo-prompt.sh ~/Documents/workspaces/my-app 001

# By name
./scripts/yolo-prompt.sh ~/Documents/workspaces/my-app implement-cli
```

**Requires:** [claude-yolo-plugin](https://github.com/bborbe/claude-yolo-plugin) installed in `~/.claude-yolo/commands/`

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

Container runs with restricted network access via **tinyproxy** (domain-based filtering) + **iptables** (enforcement):

- tinyproxy runs on `localhost:8888` with a domain allowlist
- `HTTP_PROXY`/`HTTPS_PROXY` set automatically in entrypoint
- iptables owner-match: only `root` (tinyproxy) gets direct outbound, `node` (claude) must go through proxy
- ✅ Allowed: GitHub, npm, Anthropic API, Go proxies, OSV vulnerability DB
- ❌ Blocked: Everything else (example.com fails)
- Requires `--cap-add=NET_ADMIN --cap-add=NET_RAW`

**Adding domains:** Edit `files/tinyproxy-allowlist` (regex patterns, one per line)

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

**Makefile variables:**
- `REGISTRY` - Docker registry (default: `docker.io`)
- `IMAGE` - Image name (default: `bborbe/claude-yolo`)
- `VERSION` - Auto-detected from git tags (override: `make build VERSION=custom`)

**Network allowlist:** Edit `files/tinyproxy-allowlist` to add/remove allowed domains (regex patterns).

**Claude model:** Edit `files/entrypoint.sh` to change `--model` flag.

**Claude Code version:** Pinned in `Dockerfile` (`ARG CLAUDE_CODE_VERSION=…`). The image bundles a specific `@anthropic-ai/claude-code` npm release rather than tracking `latest`, so a rebuild is reproducible and an upstream regression cannot land silently between image tags. To bump:

1. Pick a release from [`@anthropic-ai/claude-code` on npm](https://www.npmjs.com/package/@anthropic-ai/claude-code?activeTab=versions).
2. Edit `ARG CLAUDE_CODE_VERSION=…` in `Dockerfile`.
3. Smoke-test before tagging: build the image, set a project's `.dark-factory.yaml` `containerImage:` to the new tag, run `dark-factory daemon` against a small spec, confirm prompt generation produces files (no `Unknown command: /dark-factory:…` error from claude).
4. Tag a new claude-yolo release. Add a CHANGELOG bullet naming the new claude-code version and what motivated the bump.

Override at build time without editing: `docker buildx build --build-arg CLAUDE_CODE_VERSION=2.1.180 …`. The default pin protects unattended rebuilds; explicit override is the deliberate-bump path.

**Environment passthrough:**

- `~/.claude-yolo/env` — if present, auto-loaded into the container. One `KEY=VALUE` per line (Docker `--env-file` format). Recommended: `chmod 600 ~/.claude-yolo/env` (typically contains secrets).
- `--env-file <path>` or `--env-file=<path>` — pass an additional env file for this invocation. May be supplied multiple times. Leading `~` in the path is expanded to `$HOME` (both forms). Explicit flags override the default file on key collision.

Example `~/.claude-yolo/env`:

```
GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
NPM_TOKEN=npm_xxxxxxxxxxxxxxxxxxxx
```

The file path follows `CLAUDE_YOLO_DIR` — if you've overridden it, the auto-loaded file is `$CLAUDE_YOLO_DIR/env`.

## Project Structure

```
claude-yolo/
├── Dockerfile             # Container definition
├── Makefile               # Build/run helpers
├── README.md
├── files/                 # Files copied into container image
│   ├── entrypoint.sh      # Container init (sets proxy env vars)
│   ├── init-firewall.sh   # Starts tinyproxy + iptables rules
│   ├── tinyproxy.conf     # Proxy configuration
│   ├── tinyproxy-allowlist # Domain allowlist (regex patterns)
│   └── stream-formatter.py # Parse stream-json output for one-shot mode
├── scripts/               # Helper scripts (run on host)
│   ├── yolo-run.sh        # Launch container (interactive or one-shot)
│   └── yolo-prompt.sh     # Execute prompts via /run-prompt
└── examples/
    └── CLAUDE.md          # Sample workflow configuration
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

## Troubleshooting

### `Claude OAuth token missing or expired in ~/.claude-yolo`

Refresh the YOLO Claude session — see [Authenticate the YOLO Claude session](#3-authenticate-the-yolo-claude-session). The token in `~/.claude-yolo/.credentials.json` expires periodically and is independent of your main `~/.claude` login.

### Healthcheck `claude` probe fails with `stdout=""` / container exits non-zero

Two distinct causes; check both:

1. **Expired YOLO OAuth token** — refresh per the section above.
2. **Missing Linux capabilities on OrbStack / rootless Docker** — the entrypoint's `init-firewall.sh` calls `iptables`, which OrbStack rejects without `NET_ADMIN` + `NET_RAW`. Any wrapper invoking the image directly MUST pass:

   ```bash
   docker run --rm \
     --cap-add=NET_ADMIN --cap-add=NET_RAW \
     -v ~/.claude-yolo:/home/node/.claude \
     -v <project>:/workspace \
     docker.io/bborbe/claude-yolo:latest \
     <command>
   ```

   Symptom without the caps: `iptables: Permission denied (you must be root)` and the entrypoint exits non-zero before `claude` ever starts.

### `Not logged in · Please run /login` inside an interactive YOLO session

The host token file is missing or unreadable from the container. Run `/login` inside the session as instructed — the credentials write back to `~/.claude-yolo` and persist for the next container.

## License

BSD-2-Clause
