---
status: completed
summary: Updated MODEL resolution in files/entrypoint.sh to prefer ANTHROPIC_MODEL over YOLO_MODEL, and added the Unreleased CHANGELOG entry.
container: claude-yolo-exec-011-model-env-anthropic-compat
dark-factory-version: v0.162.0
created: "2026-05-19T21:25:00Z"
queued: "2026-05-19T19:29:30Z"
started: "2026-05-19T19:29:40Z"
completed: "2026-05-19T19:30:07Z"
---

<summary>
- The entrypoint resolves the model via `${YOLO_MODEL:-sonnet}`, but dark-factory (and Anthropic-compatible providers like MiniMax) use the standard `ANTHROPIC_MODEL` env var — these don't compose
- Switch the resolution order to prefer `ANTHROPIC_MODEL`, falling back to `YOLO_MODEL` for backward compatibility, then to `sonnet`
- Result: setting `ANTHROPIC_MODEL=MiniMax-M2.7` (or any non-Anthropic model) makes claude CLI honor `ANTHROPIC_BASE_URL` and route to alt-providers; legacy `YOLO_MODEL` users keep working
- No behavioral change when neither env is set (still defaults to `sonnet`)
</summary>

<objective>
Make `ANTHROPIC_MODEL` the canonical env var for selecting the claude model inside the YOLO container, while keeping `YOLO_MODEL` working as a legacy fallback.
</objective>

<context>
Read `CLAUDE.md` for project conventions.
Read `docs/dod.md` for the project's definition of done.

Files to read in full before editing:
- `files/entrypoint.sh` — current MODEL resolution at line 49
- `CHANGELOG.md` — to add the `## Unreleased` entry; if the section does not exist directly above `## v0.7.0`, create it
</context>

<requirements>

## 1. Update MODEL resolution in `files/entrypoint.sh`

Edit `files/entrypoint.sh`. Replace the existing line (currently line 49):

```bash
MODEL="${YOLO_MODEL:-sonnet}"
```

with:

```bash
MODEL="${ANTHROPIC_MODEL:-${YOLO_MODEL:-sonnet}}"
```

Precedence: `ANTHROPIC_MODEL` wins; if unset, fall back to `YOLO_MODEL`; if both unset, default to `sonnet`. Existing callers that set `YOLO_MODEL` continue to work.

## 2. Add CHANGELOG entry

If `CHANGELOG.md` does not already have an `## Unreleased` section above the topmost released version header (currently `## v0.7.0`), create one. Then add the bullet under it:

```
- feat: honor `ANTHROPIC_MODEL` env var for model selection (preferred over legacy `YOLO_MODEL`; falls back to `YOLO_MODEL`, then `sonnet`). Required for dark-factory and Anthropic-compatible alt-providers (MiniMax, etc.) to route correctly when `ANTHROPIC_BASE_URL` is set.
```

After the edit, the top of `CHANGELOG.md` (after the preamble) should look like:

```
## Unreleased

- feat: honor `ANTHROPIC_MODEL` env var for model selection (preferred over legacy `YOLO_MODEL`; falls back to `YOLO_MODEL`, then `sonnet`). Required for dark-factory and Anthropic-compatible alt-providers (MiniMax, etc.) to route correctly when `ANTHROPIC_BASE_URL` is set.

## v0.7.0
...
```

</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Edit ONLY `files/entrypoint.sh` and `CHANGELOG.md`; in `CHANGELOG.md` you may add the `## Unreleased` header if it does not already exist.
- Keep the line valid under `set -euo pipefail` — the `${VAR:-...}` form is safe for unset vars.
- Do not rename `YOLO_MODEL` to `ANTHROPIC_MODEL` in the historical CHANGELOG.md entry at line 142 — preserve historical records.
- Do not introduce a deprecation warning for `YOLO_MODEL` in this change — silent fallback only.
- shellcheck must pass — `make precommit` runs `shellcheck files/*.sh scripts/*.sh`.
</constraints>

<verification>
Run `make precommit` in `/workspace` — must exit 0.

Additional checks:
1. `grep -nF '${ANTHROPIC_MODEL:-${YOLO_MODEL:-sonnet}}' files/entrypoint.sh` — returns exactly one line.
2. `grep -nF '${YOLO_MODEL:-sonnet}' files/entrypoint.sh` — returns zero lines (the old resolution must be gone).
3. `grep -nF '- feat: honor `ANTHROPIC_MODEL`' CHANGELOG.md` — returns at least one line.
4. `grep -n '^## Unreleased' CHANGELOG.md` — returns exactly one line, positioned above `## v0.7.0`.
5. `shellcheck files/entrypoint.sh` — exits 0.
</verification>
