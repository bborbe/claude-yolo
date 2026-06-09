---
status: verifying
tags:
    - dark-factory
    - spec
approved: "2026-06-09T12:32:58Z"
generating: "2026-06-09T12:38:17Z"
prompted: "2026-06-09T12:38:17Z"
verifying: "2026-06-09T12:44:37Z"
branch: dark-factory/env-passthrough
---

## Summary

- Users running `yolo-run.sh` cannot easily pass secrets (GitHub tokens, NPM tokens, etc.) into the YOLO container without mounting their full shell config, which defeats the isolation goal.
- Add a default convention: if `~/.claude-yolo/env` exists on the host, the launcher auto-loads it into the container. Zero-config, set-once-and-forget — mirrors how `~/.claude-yolo/CLAUDE.md` is already auto-mounted.
- Add a per-invocation flag `--env-file <path>` so a single call can point at an alternate file (project-local `.env.yolo`, CI secrets, ad-hoc experiments). Both can be combined.
- Use Docker's native `--env-file` flag — no custom parser, format is `KEY=VALUE` per line by Docker contract.
- Refactor the existing positional argument parsing in `scripts/yolo-run.sh` (currently a brittle `$1`-is-path-or-prompt heuristic) into an explicit option loop so the new flag and the existing positional `[path] ["prompt"]` coexist cleanly.

## Problem

`scripts/yolo-run.sh` runs Claude inside an isolated container. The isolation is the point — no host shell, no SSH agent, no kubectl contexts — but it also means anything the in-container Claude needs (e.g. a `GH_TOKEN` to open a PR, an `NPM_TOKEN` to publish) currently has no first-class path in. The previous workaround patterns are all bad: mounting `~/.zshrc` re-introduces host aliases and broken paths; setting `-e GH_TOKEN=...` ad-hoc per call requires editing the script; an env allowlist (`YOLO_ENV_PASSTHROUGH=GH_TOKEN,...`) is silent when a name is forgotten and hard to audit. There is no obvious, documented, isolation-preserving way to hand secrets to the container today.

## Goal

After this change, a user can drop key/value pairs in `~/.claude-yolo/env` once and every subsequent `yolo-run.sh` invocation makes those variables available to Claude inside the container. For one-off or per-project secrets, a user can pass `--env-file <path>` to a single invocation. Both can be combined. The host shell is never mounted, no allowlist is maintained, and the launcher script remains shellcheck-clean.

## Non-goals

- Do NOT introduce an env-name allowlist (`YOLO_ENV_PASSTHROUGH=GH_TOKEN,NPM_TOKEN`) — invariant; rejected on auditability and silent-omission grounds. If a future caller demands host-shell passthrough by name, that's a separate spec.
- Do NOT mount `~/.zshrc`, `~/.bashrc`, or any host shell rc file — defeats isolation.
- Do NOT parse, validate, or rewrite the env file's contents in bash — Docker's `--env-file` defines the format; the script is a pass-through.
- Do NOT enforce filesystem permissions on `~/.claude-yolo/env` (no `chmod 600` check). Document the recommendation; do not police it.
- Do NOT add a `--no-env-file` opt-out or any flag that disables the default auto-load — invariant; if a future consumer demands variation, that's a separate spec. Users wanting to skip the default file can delete or rename it.
- Do NOT change how `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`, or `YOLO_PROMPT` are passed today — those remain explicit `-e` flags.

## Desired Behavior

1. If the file `~/.claude-yolo/env` exists on the host at launch time, the launcher passes it to `docker run` as an `--env-file` argument, so all `KEY=VALUE` entries become environment variables inside the container.
2. If `~/.claude-yolo/env` does not exist, the launcher proceeds normally and does not error or warn.
3. A new flag `--env-file <path>` is accepted by `yolo-run.sh`. The GNU `--env-file=<path>` form is also accepted and behaves identically. When present, the given path is passed to `docker run` as an additional `--env-file` argument (always in space-form, since `docker run` does not accept the `=` syntax for `--env-file`).
4. When both the default file exists AND `--env-file <path>` is supplied, both are forwarded. Order matches Docker semantics: the default file is forwarded first, then the explicit `--env-file` flag, so explicit overrides default for any colliding key.
5. The flag `--env-file` may be supplied multiple times in one invocation; each occurrence is forwarded to `docker run` in the order given.
6. If `--env-file <path>` references a path that does not exist, the launcher exits non-zero with an error message naming the missing path, before starting the container.
7. The existing positional arguments `[path] ["prompt"]` continue to work exactly as before — the path-vs-prompt heuristic for a single positional argument is preserved, two positionals are still `path prompt`.
8. `--env-file` may appear before, after, or interleaved with the positional arguments on the command line and is interpreted the same way in all positions.
9. A leading `~` or `~/` in the `--env-file` path (both space-form and `=`-form) is expanded to `$HOME` by the launcher before the existence check and before forwarding to `docker run`. Rationale: in the `=`-form (`--env-file=~/.env`) and inside quotes, the shell does NOT expand `~`, so users naturally writing `~/.claude-yolo/env` would otherwise hit a "file does not exist" error.

## Constraints

- `scripts/yolo-run.sh` must pass `shellcheck` (run via `make precommit`). No new warnings.
- `set -euo pipefail` at the top of the script stays. New code must be safe under `-u` (no unbound variable expansions).
- The container image (`Dockerfile`, `files/`) is not modified by this spec — passthrough is host-side only.
- The existing `-e ANTHROPIC_BASE_URL`, `-e ANTHROPIC_AUTH_TOKEN`, `-e ANTHROPIC_MODEL`, `-e YOLO_PROMPT` lines stay untouched.
- The default config directory remains `${CLAUDE_YOLO_DIR:-$HOME/.claude-yolo}`. The default env file is `$CLAUDE_YOLO_DIR/env` — i.e. it follows `CLAUDE_YOLO_DIR` if the user has overridden it, matching how `CLAUDE.md` is found today.
- CHANGELOG entry goes under `## Unreleased`. No manual version bump — `release.autoRelease: true` in `.maintainer.yaml` means github-releaser cuts the tag after master merge.
- Container verification (running `docker build`, launching the container) is out of scope for verification commands — the dark-factory container has no Docker-in-Docker. Acceptance criteria use only `shellcheck`, `grep`, and file inspection.

## Failure Modes

| Trigger | Detection | Expected behavior | Recovery | Reversibility |
|---|---|---|---|---|
| `~/.claude-yolo/env` does not exist | `[ -f "$ENV_FILE" ]` returns false | Launcher proceeds without `--env-file`; no warning printed | None needed | n/a |
| `--env-file /missing/path` supplied | `[ -f "$path" ]` returns false during arg parsing | Launcher prints `ERROR: --env-file path does not exist: /missing/path` to stderr and exits non-zero before invoking `docker run` | User corrects the path and reruns | Reversible — no container started, no lock file written |
| `~/.claude-yolo/env` exists but is malformed (e.g. blank lines, comments, syntax Docker rejects) | Surfaced by `docker run` itself, not by the launcher | Launcher does not pre-validate; `docker run` errors are propagated as its own non-zero exit | User fixes the file and reruns | Reversible — failed `docker run` leaves no lock file (lock is written after `docker run` succeeds; see ordering in current script line 71) |
| `~/.claude-yolo/env` is world-readable (mode 644) | Not detected by the launcher | Launcher does not enforce permissions; documentation recommends `chmod 600` | User runs `chmod 600 ~/.claude-yolo/env` | n/a |
| `--env-file` flag supplied without a following argument | `shift` past end / `$#` check during arg parsing | Launcher prints `ERROR: --env-file requires a path argument` to stderr and exits non-zero | User supplies a path | Reversible — no container started |
| User writes `--env-file=~/.env` (tilde in `=`-form, unexpanded by shell) | Without tilde expansion the path would not exist | Launcher expands leading `~` / `~/` to `$HOME` before existence check; path resolves | n/a — by design | Reversible |
| Same key defined in default file and explicit `--env-file` | n/a | Explicit `--env-file` wins (Docker semantics: later `--env-file` overrides earlier) | n/a — by design | n/a |

## Security / Abuse Cases

- **What an attacker can control**: the contents of `~/.claude-yolo/env` if they have write access to the user's home dir — but that already implies full account compromise. The launcher does not download, fetch, or interpret the file beyond handing the path to Docker.
- **Trust boundary**: the env file crosses host → container. Anything in it becomes an in-container environment variable, readable by any process running as the `node` user inside the container, including Claude and any tool it invokes. This is the intended behavior — same trust profile as today's `-e ANTHROPIC_AUTH_TOKEN`.
- **Path injection**: `--env-file <path>` is passed directly to `docker run`; no shell evaluation of the path's contents. The launcher's only handling is `[ -f "$path" ]` (existence check) and quoting the variable when forwarding it.
- **Documentation must call out** that the recommended permission for `~/.claude-yolo/env` is `chmod 600`, since it will typically contain secrets.

## Acceptance Criteria

- [ ] `scripts/yolo-run.sh` accepts both `--env-file <path>` (space-form) AND `--env-file=<path>` (GNU `=`-form) — evidence: `grep -nE '^\s*--env-file\)' scripts/yolo-run.sh` returns ≥1 line (space-form case-branch header), AND `grep -nE '^\s*--env-file=\*\)' scripts/yolo-run.sh` returns ≥1 line (`=`-form case-branch header).
- [ ] Leading `~` / `~/` in the path is expanded to `$HOME` — evidence: `grep -nE 'HOME.*~|~.*HOME' scripts/yolo-run.sh` returns ≥1 line in the env-file handling code (i.e. a parameter expansion or case branch that maps a leading `~` to `$HOME` — covers idioms like `${path/#\~/$HOME}`, `"${HOME}${path#\~}"`, or a `case "$p" in "~"|"~/"*)` branch).
- [ ] Argument parsing is a `while [[ $# -gt 0 ]]; do case ... esac; done` loop, not the legacy `if [ $# -eq 1 ]` / `elif [ $# -eq 2 ]` block — evidence: `grep -nE 'while \[\[ \$# ' scripts/yolo-run.sh` returns a match AND `grep -nE 'elif \[ \$# -eq 2 \]' scripts/yolo-run.sh` returns no match (legacy block removed).
- [ ] Default file auto-load logic references `$CLAUDE_YOLO_DIR/env` — evidence: `grep -n 'CLAUDE_YOLO_DIR.*/env' scripts/yolo-run.sh` returns at least one line, and the surrounding code performs a `[ -f ... ]` test before adding the `--env-file` argument.
- [ ] Forwarded `--env-file` arguments reach `docker run` — evidence: `grep -nE 'docker run' scripts/yolo-run.sh` matches a line where a bash array of env-file args (e.g. `"${ENV_FILE_ARGS[@]}"`) is interpolated into the `docker run` invocation.
- [ ] Missing `--env-file` path is rejected before container start — evidence: `grep -nE 'ERROR.*--env-file' scripts/yolo-run.sh` returns a line emitting an error to stderr followed by `exit` with non-zero status, AND `awk '/ERROR.*--env-file/{e=NR} /docker run/{d=NR} END{exit !(e<d)}' scripts/yolo-run.sh` exits 0 (error branch appears before `docker run`).
- [ ] `--env-file` without a following argument is rejected — evidence: `grep -n 'requires a path' scripts/yolo-run.sh` (or equivalent error string) returns at least one line tied to the `--env-file` case branch.
- [ ] Positional `[path] ["prompt"]` behavior is preserved — evidence: `grep -n 'git rev-parse --show-toplevel' scripts/yolo-run.sh` still returns the path-vs-prompt heuristic line, AND `TARGET_DIR` / `PROMPT` are still assigned by the parser.
- [ ] `make precommit` exits 0 from the repo root — evidence: exit code 0 (Makefile's `precommit` target runs `shellcheck` on all `.sh` scripts, so this subsumes the per-file shellcheck check).
- [ ] `README.md` documents the new flag and default file location in the `## Configuration` section — evidence: `grep -nE 'env-file|\.claude-yolo/env' README.md` returns at least two distinct lines (one for the flag, one for the default file path) within the `## Configuration` section (anchor by header, not line number).
- [ ] `README.md` documents the recommended `chmod 600` for the env file — evidence: `grep -nE 'chmod 600' README.md` returns a line in the same Configuration subsection.
- [ ] `CHANGELOG.md` has a new bullet under `## Unreleased` describing the feature — evidence: `grep -n '## Unreleased' CHANGELOG.md` returns a line, AND within the `## Unreleased` section (before the next `## ` heading) there exists a `- feat:` bullet mentioning both `--env-file` and `~/.claude-yolo/env`.
- [ ] No version bump in `CHANGELOG.md` — evidence: `git diff CHANGELOG.md` shows no new `## vX.Y.Z` heading added; only the `## Unreleased` section is modified.

(No scenario AC: behavior is verifiable via `shellcheck` + static grep; running Claude inside Docker to confirm env vars arrive is not reachable from the dark-factory container — see Constraints.)

## Verification

```
make precommit
grep -nE '^\s*--env-file\)' scripts/yolo-run.sh
grep -nE '^\s*--env-file=\*\)' scripts/yolo-run.sh
grep -nE 'HOME.*~|~.*HOME' scripts/yolo-run.sh
grep -n 'CLAUDE_YOLO_DIR.*/env' scripts/yolo-run.sh
grep -nE 'env-file|\.claude-yolo/env' README.md
grep -n '## Unreleased' CHANGELOG.md
awk '/ERROR.*--env-file/{e=NR} /docker run/{d=NR} END{exit !(e<d)}' scripts/yolo-run.sh
```

All commands exit 0; greps return at least one matching line each.

## Implementation Hints (Level 2)

The existing parser (lines 12-26) is positional-only. Replace with an explicit option loop. Sketch:

```
TARGET_DIR=""
PROMPT=""
ENV_FILE_ARGS=()
POSITIONAL=()

expand_tilde() {
    # Expand leading ~ or ~/ to $HOME (shell does NOT expand these in --env-file=~/x or in quoted strings)
    case "$1" in
        "~")     printf '%s\n' "$HOME" ;;
        "~/"*)   printf '%s\n' "$HOME/${1#\~/}" ;;
        *)       printf '%s\n' "$1" ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env-file)
            [[ $# -ge 2 ]] || { echo "ERROR: --env-file requires a path argument" >&2; exit 1; }
            envpath="$(expand_tilde "$2")"
            [[ -f "$envpath" ]] || { echo "ERROR: --env-file path does not exist: $envpath" >&2; exit 1; }
            ENV_FILE_ARGS+=(--env-file "$envpath")
            shift 2
            ;;
        --env-file=*)
            envpath="$(expand_tilde "${1#*=}")"
            [[ -f "$envpath" ]] || { echo "ERROR: --env-file path does not exist: $envpath" >&2; exit 1; }
            ENV_FILE_ARGS+=(--env-file "$envpath")
            shift
            ;;
        --) shift; POSITIONAL+=("$@"); break ;;
        -*) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
        *)  POSITIONAL+=("$1"); shift ;;
    esac
done

# Preserve existing single-arg-is-path-or-prompt heuristic on POSITIONAL.
```

Default file auto-load, applied after `CLAUDE_YOLO_DIR` is resolved and BEFORE `--env-file` flag args are appended (so flag wins on key collision):

```
DEFAULT_ENV_FILE="$CLAUDE_YOLO_DIR/env"
DEFAULT_ENV_ARGS=()
[[ -f "$DEFAULT_ENV_FILE" ]] && DEFAULT_ENV_ARGS=(--env-file "$DEFAULT_ENV_FILE")
```

`docker run` invocation grows two array splats; existing `-e` lines stay:

```
CONTAINER_ID=$(docker run -dit --rm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    "${DEFAULT_ENV_ARGS[@]}" \
    "${ENV_FILE_ARGS[@]}" \
    -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-}" \
    ...
```

Style: match the existing script — `set -euo pipefail`, `${VAR:-}` for optionals, `shellcheck disable` comments only when justified.

README addition (insert into the `## Configuration` block; anchor by section header, not line number):

```
**Environment passthrough:**
- `~/.claude-yolo/env` — if present, auto-loaded into the container. One `KEY=VALUE` per line (Docker `--env-file` format). Recommended: `chmod 600 ~/.claude-yolo/env`.
- `--env-file <path>` or `--env-file=<path>` — pass an additional env file for this invocation. May be supplied multiple times. Leading `~` in the path is expanded to `$HOME` (both forms). Explicit flags override the default file on key collision.
```

CHANGELOG addition (top of file, new section above `## v0.9.1`):

```
## Unreleased

- feat: `scripts/yolo-run.sh` now auto-loads `~/.claude-yolo/env` if present and accepts `--env-file <path>` (Docker-native flag, repeatable). Enables passing secrets like `GH_TOKEN` / `NPM_TOKEN` into the container without mounting host shell config.
```

## Do-Nothing Option

Users keep hand-editing `yolo-run.sh` to add `-e GH_TOKEN="${GH_TOKEN:-}"` lines, or mount their `.zshrc` (defeating isolation), or run Claude outside the YOLO container for any task that needs a token. The friction discourages using YOLO for the exact workflows it exists to enable (autonomous PR creation, publishing). Not acceptable.
