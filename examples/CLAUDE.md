# YOLO Container - Autonomous Execution Mode

You are running in an isolated Docker container with `--dangerously-skip-permissions` enabled.

## Critical Constraints

**Git:**
- **NO** Claude attribution in commits (no "Generated with Claude Code", no "Co-Authored-By")
- Use `cd path && git ...` (NEVER `git -C /path` - breaks auto-approval)
- Create new commits (don't amend unless explicitly blocked)

**Verification:**
- Use `make test` for verification (NEVER just `go build ./...`)
- Run `make precommit` for full validation before committing
- Tests must pass before declaring complete

**Code Quality:**
- Check project CLAUDE.md for specific patterns
- For Go: Read `~/Documents/workspaces/coding-guidelines/go-*.md`
- For Python: Read `~/Documents/workspaces/coding-guidelines/python-*.md`
- Follow established patterns in the codebase

## Workflow

1. **Understand the prompt** - Read the task specification carefully
2. **Check conventions** - Read project CLAUDE.md and relevant coding guidelines
3. **Implement** - Follow all success criteria from the prompt
4. **Verify** - Run tests (`make test`)
5. **Validate** - Run full checks (`make precommit`)

**Note:** YOLO does NOT commit or push. Management session handles git operations (has GPG key and credentials).

## Prompt Management

After executing a prompt via `/run-prompt`:
- Completed prompts are archived to `prompts/completed/`
- Management session will commit them (not YOLO)

## Completion Protocol

When task is complete:
1. **Summary** - Clearly state what was implemented
2. **Blockers** - List any issues encountered
3. **Verification** - Confirm all tests pass
4. **Exit suggestion** - Say: "Type /exit to close container"

## Project Type Detection

- **Go project** (has go.mod):
  - Read `go-architecture-patterns.md`
  - Read `go-testing-guide.md`
  - Use Ginkgo/Gomega for tests
  - Follow Interface → Constructor → Struct pattern

- **Python project** (has pyproject.toml):
  - Read `python-patterns.md`
  - Use pytest for tests
  - Follow Python conventions

- **Shell project** (*.sh files):
  - Use shellcheck
  - Follow shell best practices

## Container Environment

You are isolated with:
- ✅ Access: GitHub, npm, Anthropic API, Go proxies
- ❌ No access: kubectl, production credentials, general internet
- ✅ Mounted: Project workspace at `/workspace`
- ✅ Cache: Go modules at `/home/node/go/pkg`

Work autonomously. No permission prompts. Implement completely.
