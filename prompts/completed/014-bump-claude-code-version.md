---
status: completed
spec: ["002"]
summary: 'Bumped CLAUDE_CODE_VERSION from 2.1.169 to 2.1.197 in Dockerfile, refreshed pin-comment to name 2.1.197 as known-good, added ## Unreleased CHANGELOG entry with feat: prefix citing Sonnet 5/1M-token/background-agent/healthcheck rationale'
execution_id: claude-yolo-bump-claude-code-exec-014-bump-claude-code-version
dark-factory-version: dev
created: "2026-07-01T10:05:00Z"
queued: "2026-07-01T10:06:25Z"
started: "2026-07-01T10:06:28Z"
completed: "2026-07-01T10:07:18Z"
---

<summary>
- Bumps the pinned Claude Code version baked into the claude-yolo container from `2.1.169` to `2.1.197`
- Picks up Sonnet 5 (1M-token window), background-agent auto-resume, and 16 upstream bug fixes
- Refreshes the pin-comment so `2.1.197` is documented as the new known-good version, while preserving the "bump deliberately, smoke-test first" operator contract
- Adds a CHANGELOG entry naming the `2.1.169 → 2.1.197` transition and the dark-factory-healthcheck rationale
- Touches only two files: `Dockerfile` and `CHANGELOG.md` — no other surface changes
- Leaves the Node base, Go/updater/ast-grep versions, firewall, and scripts byte-identical
</summary>

<objective>
Update the `CLAUDE_CODE_VERSION` build arg in `Dockerfile` from `2.1.169` to `2.1.197`, refresh the surrounding pin-comment to name `2.1.197` as the new known-good version, and add a `## Unreleased` CHANGELOG entry — so the claude-yolo image ships the current upstream-stable Claude Code (Sonnet 5, 1M-token window, background-agent auto-resume, 16 bug fixes) while keeping the deliberate-bump / smoke-test protocol intact.
</objective>

<context>
Read `CLAUDE.md` for project conventions (if present).
Read `Dockerfile` in the repo root:
- Line 13 pins the version: `ARG CLAUDE_CODE_VERSION=2.1.169`
- Lines 4–12 are the pin-comment block explaining WHY the version is pinned and naming `2.1.169` as the last known-good version against dark-factory's scenario suite, ending with the "Bump deliberately: edit + tag a new claude-yolo release; smoke-test by running a dark-factory spec generation against the new image." operator contract.
- Lines 14–17 declare sibling ARGs (`GO_VERSION=1.26.4`, `UPDATER_VERSION=0.23.2`, `ASTGREP_VERSION=latest`) — these must NOT be touched.
- Line 114 consumes `${CLAUDE_CODE_VERSION}` in the `npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` step — do NOT change this line; it already parameterizes off the ARG.

Read `CHANGELOG.md` in the repo root:
- Header preamble ends at line 9.
- There is currently NO `## Unreleased` section; the newest version section is `## v0.12.0` starting at line 11.
- New entries go under a `## Unreleased` heading inserted directly above `## v0.12.0`, per `docs/dod.md`.
- For entry style, read `/home/node/.claude/plugins/marketplaces/coding/docs/changelog-guide.md`.
</context>

<requirements>
1. In `Dockerfile`, change line 13 from:
   ```
   ARG CLAUDE_CODE_VERSION=2.1.169
   ```
   to:
   ```
   ARG CLAUDE_CODE_VERSION=2.1.197
   ```
   The changed line MUST remain line 13 (do not add or remove lines above it in a way that shifts the ARG off line 13; the surrounding comment edit in step 2 keeps the same total comment-block line count).

2. In `Dockerfile`, refresh the pin-comment block (lines 4–12) so it names `2.1.197` as the current known-good version:
   - Change the sentence that currently reads (around lines 9–10) "... `2.1.169` is the last version known-good against dark-factory's scenario suite." so it names `2.1.197` as the version now known-good against dark-factory's scenario suite. You may keep `2.1.169` as historical context (e.g. "previously `2.1.169`") but that is optional.
   - PRESERVE VERBATIM IN INTENT the "Bump deliberately: edit + tag a new claude-yolo release; smoke-test by running a dark-factory spec generation against the new image." operator-contract sentence. This instruction is a durable operator contract — its meaning must survive the edit. Do not delete or weaken it.
   - Keep the 2026-06-27 incident description (the marketplace-consent gate breaking headless `claude -p` plugin discovery, dark-factory dying with `Unknown command: /dark-factory:generate-prompts-for-spec`) intact — that is the rationale for the pin discipline and must remain.
   - Keep the comment block the same number of lines (4–12) so `ARG CLAUDE_CODE_VERSION=2.1.197` stays on line 13.

3. Do NOT change the sibling ARGs. Lines 14, 16, and 17 must remain exactly:
   ```
   ARG GO_VERSION=1.26.4
   ARG UPDATER_VERSION=0.23.2
   ARG ASTGREP_VERSION=latest
   ```

4. Do NOT change any other line in `Dockerfile` — FROM, ENV, RUN stages, COPY steps, the `npm install -g` line, and ARG ordering all stay byte-identical apart from the version bump in step 1 and the comment refresh in step 2.

5. In `CHANGELOG.md`, insert a new `## Unreleased` section directly above the `## v0.12.0` heading (currently line 11), with a single bullet that:
   - Names the `2.1.169 → 2.1.197` transition explicitly.
   - Cites in one sentence that the bump is validated by `dark-factory healthcheck` passing end-to-end (the load-bearing regression check that reproduces the 2026-06-27 signature).
   - Uses a `feat:` prefix (this ships Sonnet 5 / 1M-token window / background-agent auto-resume — new capability), following the changelog-guide format `- <prefix>: <what> [context]`.
   Example (adapt wording, keep it specific):
   ```
   ## Unreleased

   - feat: bump `@anthropic-ai/claude-code` from `2.1.169` to `2.1.197` (Sonnet 5 default at 1M-token window, background-agent auto-resume, 16 bug fixes). Validated by `dark-factory healthcheck` passing all seven probes against the freshly built image — the same probe that caught the 2026-06-27 marketplace-consent regression, so the `Unknown command: /dark-factory:generate-prompts-for-spec` failure does not recur.
   ```

6. Do NOT touch any file outside `Dockerfile` and `CHANGELOG.md`. `files/`, `scripts/`, `.dark-factory.yaml`, `Makefile`, and `docs/` must all remain byte-identical.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git, the release tag, and the multi-arch publish.
- Do NOT bump the Node base tag (`FROM node:22`).
- Do NOT bump `GO_VERSION`, `UPDATER_VERSION`, or `ASTGREP_VERSION`.
- Do NOT parameterize or add tooling for future bumps — this is a one-line version change plus comment/CHANGELOG upkeep; no automation.
- `Dockerfile` structure (FROM, ARG ordering, ENV, RUN stages) unchanged apart from the single ARG line and the surrounding comment.
- The "Bump deliberately … smoke-test" instruction inside the pin comment is a durable operator contract — its meaning must survive the edit.
- CHANGELOG convention per `docs/dod.md`: new entries go under `## Unreleased`.
- Existing `make precommit` (shellcheck) must still pass.
</constraints>

<verification>
Run `make precommit` — must pass (exit 0).

```bash
# Line 13 pins the new version
grep -n '^ARG CLAUDE_CODE_VERSION=2.1.197$' Dockerfile   # expect: line 13

# Old version no longer pinned as the ARG
grep -n '^ARG CLAUDE_CODE_VERSION=2.1.169$' Dockerfile   # expect: no match (exit 1)

# New version named somewhere in the pin-comment block (lines 4-12)
grep -n '2\.1\.197' Dockerfile                            # expect: a hit in lines 4-12 AND line 13

# Sibling ARGs untouched
grep -c '^ARG GO_VERSION=1.26.4$\|^ARG UPDATER_VERSION=0.23.2$\|^ARG ASTGREP_VERSION=latest$' Dockerfile   # expect: 3

# CHANGELOG has an Unreleased bullet naming the transition + healthcheck rationale
grep -A5 '^## Unreleased$' CHANGELOG.md                    # expect: bullet naming 2.1.169 -> 2.1.197 and dark-factory healthcheck

# Exactly two files changed
git status --porcelain                                    # expect: only Dockerfile and CHANGELOG.md listed
```
</verification>
