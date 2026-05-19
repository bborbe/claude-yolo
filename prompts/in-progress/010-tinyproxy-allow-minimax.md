---
status: committing
summary: 'Added ^api\.minimax\.io$ to files/tinyproxy-allowlist after the anthropic.com entry and added ## Unreleased CHANGELOG entry for the MiniMax egress allowlist addition.'
container: claude-yolo-exec-010-tinyproxy-allow-minimax
dark-factory-version: v0.162.0
created: "2026-05-19T19:50:00Z"
queued: "2026-05-19T17:50:25Z"
started: "2026-05-19T17:50:49Z"
---

<summary>
- The YOLO container's tinyproxy egress filter currently blocks `api.minimax.io`, preventing the use of MiniMax as an Anthropic-compatible provider via `ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic`
- Add `api.minimax.io` to `files/tinyproxy-allowlist` so containers configured with the MiniMax base URL can reach the endpoint
- No other allowlist entries change; no code changes
</summary>

<objective>
Allow YOLO containers to reach `api.minimax.io` through the bundled tinyproxy so users can route Claude traffic to MiniMax's Anthropic-compatible endpoint.
</objective>

<context>
Read `CLAUDE.md` for project conventions.
Read `docs/dod.md` for the project's definition of done.

Files to read in full before editing:
- `files/tinyproxy-allowlist` — the egress allowlist; one anchored regex per line
- `CHANGELOG.md` — to add the `## Unreleased` entry
</context>

<requirements>

## 1. Add `api.minimax.io` to the allowlist

Edit `files/tinyproxy-allowlist`. Add a new line containing the anchored regex for the MiniMax API host. Match the existing line style exactly (caret-anchored, dollar-anchored, dots escaped). Insert the new line directly after `^api\.anthropic\.com$` (currently line 3) so the `api.*` hosts stay grouped together.

The new line:

```
^api\.minimax\.io$
```

## 2. Add CHANGELOG entry

If `CHANGELOG.md` does not already have an `## Unreleased` section above the topmost released version header (currently `## v0.6.3`), create one. Then add the bullet under it.

After the edit, the top of `CHANGELOG.md` should look like:

```
## Unreleased

- feat: allow `api.minimax.io` through tinyproxy egress filter for MiniMax Anthropic-compatible API

## v0.6.3
...
```

If `## Unreleased` already exists, simply append the bullet to its bullet list.

</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Edit ONLY `files/tinyproxy-allowlist` and `CHANGELOG.md`; in `CHANGELOG.md` you may add the `## Unreleased` header if it does not already exist.
- Preserve the existing line ordering of `files/tinyproxy-allowlist` — insert only the new line as specified, do not reorder existing lines.
- Match the exact regex style of the existing lines (anchored on both ends, escaped dots, no whitespace).
- Do not add wildcards (`.*`) — pin the exact host.
</constraints>

<verification>
Run `make precommit` in `/workspace` — must exit 0.

Note: `make precommit` runs `shellcheck` on shell scripts only — it does not lint the allowlist. The grep/wc checks below are the substantive verification.

1. `grep -n 'api\\.minimax\\.io' files/tinyproxy-allowlist` — returns exactly one line.
2. `wc -l < files/tinyproxy-allowlist` — returns 28 (one greater than the prior 27).
3. `grep -nF '- feat: allow' CHANGELOG.md` — returns at least one line, and that line mentions `api.minimax.io`.
4. `grep -n '^## Unreleased' CHANGELOG.md` — returns exactly one line, positioned above any released version header.
</verification>
