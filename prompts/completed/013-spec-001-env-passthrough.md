---
status: completed
spec: ["001"]
summary: 'Added Docker-native env-file passthrough to scripts/yolo-run.sh: auto-load $CLAUDE_YOLO_DIR/env, accept repeatable --env-file flag (space and GNU = forms) with tilde expansion, and preserved the legacy single-arg path-vs-prompt heuristic. Updated README Configuration section and CHANGELOG Unreleased.'
container: claude-yolo-env-passthrough-exec-013-spec-001-env-passthrough
dark-factory-version: v0.175.0
created: "2026-06-09T12:40:00Z"
queued: "2026-06-09T12:39:32Z"
started: "2026-06-09T12:39:34Z"
completed: "2026-06-09T12:44:37Z"
---

<summary>
- Users can drop secrets (e.g. `GH_TOKEN`, `NPM_TOKEN`) into `~/.claude-yolo/env` once and every subsequent YOLO run picks them up automatically — same set-once-and-forget pattern as `~/.claude-yolo/CLAUDE.md`.
- A new `--env-file <path>` flag (and the GNU `--env-file=<path>` form) lets a single invocation pass an additional env file, repeatable, with explicit flags winning over the default file on key collision.
- Leading `~` or `~/` in `--env-file` paths is expanded to `$HOME` because the shell does NOT expand tilde inside `--env-file=~/...` or quoted strings.
- Missing `--env-file` paths fail fast before the container starts; a missing default file is silently skipped.
- The brittle positional `$1`-is-path-or-prompt heuristic is replaced with an explicit option loop that still honors `[path] ["prompt"]` and the existing single-arg detection.
- The host shell is never mounted, no allowlist is introduced, and no opt-out flag is added (both invariants from the spec).
- README documents the new flag and recommends `chmod 600` for the env file; CHANGELOG gets an `## Unreleased` entry (no version bump — github-releaser cuts the tag after merge).
</summary>

<objective>
Add Docker-native env-file passthrough to `scripts/yolo-run.sh`: auto-load `$CLAUDE_YOLO_DIR/env` if present, accept `--env-file <path>` / `--env-file=<path>` (repeatable), and refactor the existing positional parser into an explicit option loop so both coexist cleanly. Document the feature in `README.md` and `CHANGELOG.md`.
</objective>

<context>
Read `CLAUDE.md` for project conventions.
Read `docs/dod.md` for the project's definition of done.

Files to read in full before editing:
- `scripts/yolo-run.sh` — current state. Note in particular:
  - The `CLAUDE_YOLO_DIR` resolution at line 10: `CLAUDE_YOLO_DIR="${CLAUDE_YOLO_DIR:-$HOME/.claude-yolo}"` — your default env file must follow this, not hardcoded `$HOME/.claude-yolo`.
  - The legacy positional parser at lines 12-26 (the `if [ $# -eq 1 ]; then ... elif [ $# -eq 2 ]; then ...` block). The single-arg branch uses a path-vs-prompt heuristic: tests `[ -d "$1" ] || [ -f "$1" ] || (cd "$1" && git rev-parse --show-toplevel) >/dev/null 2>&1`. This heuristic MUST be preserved when the option loop processes positionals.
  - The `docker run` invocation at lines 59-68 — your two array splats (`DEFAULT_ENV_ARGS`, `ENV_FILE_ARGS`) go BEFORE the existing `-e ANTHROPIC_*` lines. The existing `-e` lines stay untouched.
  - The `# shellcheck disable=SC2064` comment at line 81 is for an unrelated trap line — do not remove or move it.
- `README.md` — find the `## Configuration` section (currently around line 243). Anchor edits by section header, not line number.
- `CHANGELOG.md` — top section. Insert a new `## Unreleased` heading above `## v0.9.1` (current top released entry).
- `.dark-factory.yaml` — confirms `validationCommand: "make precommit"` and `testCommand: "make test"`. The dark-factory container has shellcheck but no Docker; do not attempt to run `docker build` or `docker run` in verification.
</context>

<requirements>

## 1. Refactor `scripts/yolo-run.sh` argument parser

Replace the legacy positional block (currently lines 12-26):

```bash
TARGET_DIR="."
PROMPT=""

# Parse arguments
if [ $# -eq 1 ]; then
    # Could be path OR prompt
    if [ -d "$1" ] || [ -f "$1" ] || (cd "$1" && git rev-parse --show-toplevel) >/dev/null 2>&1; then
        TARGET_DIR="$1"
    else
        PROMPT="$1"
    fi
elif [ $# -eq 2 ]; then
    TARGET_DIR="$1"
    PROMPT="$2"
fi
```

with an explicit option loop. The replacement MUST:

1. Initialize four variables at the top: `TARGET_DIR="."`, `PROMPT=""`, and two bash arrays `ENV_FILE_ARGS=()` and `POSITIONAL=()`.
2. Define a helper `expand_tilde()` that maps leading `~` or `~/` to `$HOME` using a case statement. Required form:

   ```bash
   expand_tilde() {
       # Expand leading ~ or ~/ to $HOME (shell does NOT expand these in --env-file=~/x or in quoted strings)
       case "$1" in
           "~")     printf '%s\n' "$HOME" ;;
           "~/"*)   printf '%s\n' "$HOME/${1#\~/}" ;;
           *)       printf '%s\n' "$1" ;;
       esac
   }
   ```

3. Loop with `while [[ $# -gt 0 ]]; do case "$1" in ... esac; done`. Cases required:
   - `--env-file)` — space form. Guard with `[[ $# -ge 2 ]] || { echo "ERROR: --env-file requires a path argument" >&2; exit 1; }`. Then `envpath="$(expand_tilde "$2")"`, check `[[ -f "$envpath" ]] || { echo "ERROR: --env-file path does not exist: $envpath" >&2; exit 1; }`, then `ENV_FILE_ARGS+=(--env-file "$envpath")`, then `shift 2`.
   - `--env-file=*)` — GNU `=` form. Extract via `envpath="$(expand_tilde "${1#*=}")"`. Note: an empty value (`--env-file=`) means `${1#*=}` is the empty string; the subsequent `[[ -f "$envpath" ]]` check will fail with the "does not exist" error — that is the correct behavior, do not add a separate empty-string branch. Then same `[[ -f ... ]]` check and same `ENV_FILE_ARGS+=(--env-file "$envpath")`, then `shift`.
   - `--)` — end-of-options sentinel: `shift; POSITIONAL+=("$@"); break`.
   - `-*)` — unknown option: `echo "ERROR: unknown option: $1" >&2; exit 1`.
   - `*)` — positional: `POSITIONAL+=("$1"); shift`.

4. AFTER the loop, replicate the legacy single-arg / two-arg semantics on `POSITIONAL`. Use `${#POSITIONAL[@]}` to count and the same path-vs-prompt heuristic. Important: under `set -u`, expanding an empty array with `"${POSITIONAL[@]}"` is unbound on older bash — guard with the count first. Required form:

   ```bash
   if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
       arg="${POSITIONAL[0]}"
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
   ```

   (Zero positionals → defaults `TARGET_DIR="."`, `PROMPT=""` stand, matching the legacy zero-arg behavior.)

## 2. Add default-env-file auto-load

AFTER `CLAUDE_YOLO_DIR` is resolved (currently line 10, which stays unchanged) and BEFORE the `docker run` invocation, add:

```bash
DEFAULT_ENV_FILE="$CLAUDE_YOLO_DIR/env"
DEFAULT_ENV_ARGS=()
if [[ -f "$DEFAULT_ENV_FILE" ]]; then
    DEFAULT_ENV_ARGS=(--env-file "$DEFAULT_ENV_FILE")
fi
```

Place this block somewhere between the existing `CLAUDE_YOLO_DIR=` line and the `echo "Starting claude-yolo container..."` line. A natural slot is right before `echo "Starting claude-yolo container..."` (after the lock-file handling) so all guards have already run, but anywhere in that window is fine.

The location matters for ordering: `DEFAULT_ENV_ARGS` MUST be splatted into `docker run` BEFORE `ENV_FILE_ARGS` so that any keys defined in both win in favor of the explicit flag (Docker semantics: later `--env-file` overrides earlier).

If `$DEFAULT_ENV_FILE` does not exist: leave `DEFAULT_ENV_ARGS` empty. No warning, no error.

## 3. Splat both arrays into `docker run`

Modify the `docker run` invocation (currently lines 59-68). The existing `-e ANTHROPIC_BASE_URL`, `-e ANTHROPIC_AUTH_TOKEN`, `-e ANTHROPIC_MODEL`, `-e YOLO_PROMPT` lines stay untouched. Insert the two array splats BEFORE them:

```bash
CONTAINER_ID=$(docker run -dit --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    "${DEFAULT_ENV_ARGS[@]}" \
    "${ENV_FILE_ARGS[@]}" \
    -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-}" \
    -e ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}" \
    -e ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-}" \
    -e YOLO_PROMPT="$PROMPT" \
    -v "$GIT_ROOT:/workspace" \
    -v "$CLAUDE_YOLO_DIR:/home/node/.claude" \
    docker.io/bborbe/claude-yolo:latest)
```

`set -u` safety: bash 4+ treats `"${ARR[@]}"` on an empty declared array as safe (expands to nothing). Both arrays are explicitly initialized as `=()` above the loop / above the auto-load block, so they are always declared by the time `docker run` executes. Do NOT add `${ARR[@]:-}` guards — that form expands an empty array to a single empty string, which would pass a bogus empty argument to `docker run`.

## 4. Update the usage comment block at the top of `scripts/yolo-run.sh`

The current comment block (lines 4-8):

```bash
# Usage: yolo-run.sh [path] ["prompt"]
# If no path given, use current directory
# If prompt given, run one-shot mode (execute prompt and exit)
# Environment:
#   CLAUDE_YOLO_DIR  Path to Claude config directory (default: ~/.claude-yolo)
```

Replace with:

```bash
# Usage: yolo-run.sh [--env-file <path>]... [path] ["prompt"]
# If no path given, use current directory
# If prompt given, run one-shot mode (execute prompt and exit)
# --env-file <path>  Pass an env file to docker run (repeatable). GNU --env-file=<path> form also accepted.
#                    Leading ~ or ~/ in the path is expanded to $HOME.
# Environment:
#   CLAUDE_YOLO_DIR  Path to Claude config directory (default: ~/.claude-yolo)
#                    If $CLAUDE_YOLO_DIR/env exists, it is auto-loaded into the container.
```

## 5. Update `README.md`

Locate the `## Configuration` section (currently around line 243). Append a new subsection at the END of that Configuration block, BEFORE the next top-level section (currently `## Project Structure`). The new subsection MUST contain both the default file path AND the flag, plus the `chmod 600` recommendation:

```markdown
**Environment passthrough:**

- `~/.claude-yolo/env` — if present, auto-loaded into the container. One `KEY=VALUE` per line (Docker `--env-file` format). Recommended: `chmod 600 ~/.claude-yolo/env` (typically contains secrets).
- `--env-file <path>` or `--env-file=<path>` — pass an additional env file for this invocation. May be supplied multiple times. Leading `~` in the path is expanded to `$HOME` (both forms). Explicit flags override the default file on key collision.

Example `~/.claude-yolo/env`:

```
GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
NPM_TOKEN=npm_xxxxxxxxxxxxxxxxxxxx
```

The file path follows `CLAUDE_YOLO_DIR` — if you've overridden it, the auto-loaded file is `$CLAUDE_YOLO_DIR/env`.
```

Anchor by `## Configuration` section header, not line number. Place the subsection inside that section, after the existing bullets ("Claude model: Edit `files/entrypoint.sh` ...") and before the next `## ` heading.

## 6. Update `CHANGELOG.md`

Add a new `## Unreleased` section above `## v0.9.1` (current top entry). If `## Unreleased` already exists (it does not as of this writing — verify with `grep -n '## Unreleased' CHANGELOG.md`), append the bullet under it; otherwise create the heading first.

Bullet to add:

```
- feat: `scripts/yolo-run.sh` now auto-loads `~/.claude-yolo/env` if present and accepts `--env-file <path>` (Docker-native flag, repeatable). Enables passing secrets like `GH_TOKEN` / `NPM_TOKEN` into the container without mounting host shell config.
```

Do NOT add a `## vX.Y.Z` heading. `release.autoRelease: true` in `.maintainer.yaml` (post-merge release tagging by github-releaser) cuts the tag automatically after master merge — distinct from `.dark-factory.yaml`'s `autoRelease: false`, which only suppresses per-prompt feature-branch tagging during dark-factory execution. The two settings are not in conflict; they govern different release moments.

After the edit, the top of `CHANGELOG.md` (after the preamble) should look like:

```
## Unreleased

- feat: `scripts/yolo-run.sh` now auto-loads `~/.claude-yolo/env` if present and accepts `--env-file <path>` (Docker-native flag, repeatable). Enables passing secrets like `GH_TOKEN` / `NPM_TOKEN` into the container without mounting host shell config.

## v0.9.1

- bump Go to 1.26.4
```

</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Edit ONLY `scripts/yolo-run.sh`, `README.md`, and `CHANGELOG.md`. Do not touch `Dockerfile`, `files/`, `Makefile`, or `scripts/yolo-prompt.sh`.
- `scripts/yolo-run.sh` must pass `shellcheck` (run via `make precommit`). No new warnings, no new `# shellcheck disable=` comments unless genuinely required and justified inline.
- Keep `set -euo pipefail` at the top of the script. All new code must be safe under `-u` — use `${VAR:-}` for any optional scalar, and only expand `"${ARR[@]}"` on arrays that have been explicitly declared with `=()`.
- Do NOT introduce an env-name allowlist (`YOLO_ENV_PASSTHROUGH=GH_TOKEN,...`) — invariant, rejected on auditability grounds.
- Do NOT mount `~/.zshrc`, `~/.bashrc`, or any host shell rc file — defeats isolation.
- Do NOT parse, validate, or rewrite the env file's contents in bash — Docker's `--env-file` defines the format; the script is a pure pass-through.
- Do NOT enforce filesystem permissions on the env file (no `chmod 600` check). Document the recommendation; do not police it.
- Do NOT add a `--no-env-file` opt-out or any flag that disables the default auto-load — invariant. Users who want to skip the default can rename or delete it.
- Do NOT change how `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`, or `YOLO_PROMPT` are passed today — those remain explicit `-e` lines.
- Do NOT add a version heading to `CHANGELOG.md` — only the `## Unreleased` section is modified.
- Container verification (running `docker build`, launching the container) is out of scope — the dark-factory container has no Docker-in-Docker.
</constraints>

<verification>
Run `make precommit` from the repo root — must exit 0 (this runs `shellcheck` on all `.sh` scripts).

Additional static checks (each must return ≥1 matching line unless noted):

1. `grep -nE '^\s*--env-file\)' scripts/yolo-run.sh` — space-form case branch present.
2. `grep -nE '^\s*--env-file=\*\)' scripts/yolo-run.sh` — GNU `=`-form case branch present.
3. `grep -nE 'HOME.*~|~.*HOME' scripts/yolo-run.sh` — tilde expansion code present (the `expand_tilde` body).
4. `grep -n 'CLAUDE_YOLO_DIR.*/env' scripts/yolo-run.sh` — default file references `$CLAUDE_YOLO_DIR/env`.
5. `grep -nE 'while \[\[ \$# ' scripts/yolo-run.sh` — explicit option loop present.
6. `grep -nE 'elif.*\$# -eq 2' scripts/yolo-run.sh` — must return ZERO lines (legacy block removed; pattern matches both `[ $# -eq 2 ]` and `[[ $# -eq 2 ]]` forms).
7. `grep -nE '\$\{DEFAULT_ENV_ARGS\[@\]\}|\$\{ENV_FILE_ARGS\[@\]\}' scripts/yolo-run.sh` — both array splats reach the `docker run` invocation.
8. `awk '/ERROR.*--env-file/{e=NR} /docker run/{d=NR} END{exit !(e<d)}' scripts/yolo-run.sh` — exit code 0 (error branch appears before `docker run`).
9. `grep -n 'requires a path' scripts/yolo-run.sh` — missing-arg error string present.
10. `grep -n 'git rev-parse --show-toplevel' scripts/yolo-run.sh` — path-vs-prompt heuristic preserved.
11. `grep -nE 'env-file|\.claude-yolo/env' README.md` — at least two distinct matching lines (flag + default file path) in the Configuration section.
12. `grep -nE 'chmod 600' README.md` — recommendation present.
13. `grep -n '## Unreleased' CHANGELOG.md` — at least one matching line, positioned above `## v0.9.1`. (Use `[[ $(grep -c '## Unreleased' CHANGELOG.md) -eq 1 ]]` if you want to assert single-occurrence; the spec AC requires ≥1.)
14. Within the `## Unreleased` section of `CHANGELOG.md` (before the next `## ` heading) there is a `- feat:` bullet mentioning both `--env-file` and `~/.claude-yolo/env`.
15. `git diff CHANGELOG.md` shows NO new `## vX.Y.Z` heading added — only the `## Unreleased` section is new.
</verification>
</content>
</invoke>