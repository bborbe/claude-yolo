---
status: completed
summary: Added ARG ASTGREP_VERSION=latest and extended npm install line to include @ast-grep/cli
container: claude-yolo-exec-012-add-ast-grep-to-image
dark-factory-version: v0.173.0
created: "2026-05-31T18:15:55Z"
queued: "2026-05-31T18:38:35Z"
started: "2026-05-31T18:38:45Z"
completed: "2026-05-31T18:39:23Z"
---

<summary>
- pr-reviewer agent runs inside claude-yolo container and invokes /coding:pr-review
- The pr-review dispatcher's mechanical-rules step (Phase 4 of the doc-driven rule base in bborbe/coding) shells out to ast-grep
- Without ast-grep on $PATH inside the container, the mechanical step silently no-ops in prod and only judgment-tier LLM rules run
- Install via the existing `npm install -g` line; `@ast-grep/cli` is the official npm package and ships prebuilt arm64/amd64 binaries
</summary>

<objective>
Add the ast-grep CLI to the claude-yolo image so the pr-reviewer agent can run the doc-driven code-review pipeline's mechanical rules step. Pin the version via a new ARG with default `latest` — mirrors the existing `CLAUDE_CODE_VERSION` pattern so operators can override at build time.
</objective>

<context>
Read `CLAUDE.md` for project conventions.
Read `Dockerfile` — note:
- The existing `ARG` block at the top (lines 1-7): `TZ`, `CLAUDE_CODE_VERSION=latest`, `GO_VERSION`, `TARGETARCH`, `UPDATER_VERSION`.
- The existing `RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` line around line 103 (under the `USER node` block).

The convention to mirror: `ARG CLAUDE_CODE_VERSION=latest` at the top, `${CLAUDE_CODE_VERSION}` interpolation in the install line. We follow the same shape for ast-grep.

Reference: `@ast-grep/cli` on npm — https://www.npmjs.com/package/@ast-grep/cli — ships prebuilt binaries for darwin/linux × arm64/amd64.
</context>

<requirements>
1. Add `ARG ASTGREP_VERSION=latest` to the Dockerfile ARG block at the top, alongside the existing ARGs (place it after `UPDATER_VERSION`).
2. Extend the existing `RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` line to also install `@ast-grep/cli@${ASTGREP_VERSION}`. Use a multi-line continuation so the diff is reviewable:
   ```dockerfile
   RUN npm install -g \
       @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
       @ast-grep/cli@${ASTGREP_VERSION}
   ```
3. Do NOT add a separate `RUN` step — sharing the existing one keeps the image layer count down and matches the existing pattern.
4. Do NOT change anything else in the Dockerfile (no reordering, no comment edits, no other tool additions).
5. Verify by running `make precommit` — should pass (it runs `shellcheck` on `.sh` files; the Dockerfile is not linted, so the gate only catches regressions in scripts).
6. Add a `## Unreleased` section to `CHANGELOG.md` directly above the current `## v0.8.1` heading (CHANGELOG has no Unreleased block today — create the header). Under it add one bullet:
   ```
   - feat: add `@ast-grep/cli` to the image (new `ARG ASTGREP_VERSION=latest`) so the pr-reviewer agent's mechanical-rules step can run.
   ```
   `autoRelease: true` will roll this into the next tagged release on merge.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Do NOT modify `files/tinyproxy-allowlist` — npm install reaches `registry.npmjs.org`, which is already in the allowlist (existing `claude-code` install confirms this).
- Do NOT pin `ASTGREP_VERSION` to a specific version — `latest` matches the existing `CLAUDE_CODE_VERSION` convention; operators override per-build via `--build-arg ASTGREP_VERSION=0.43.0`.
- Preserve existing Dockerfile formatting: indentation style, comment style, ARG block ordering.
- Do NOT touch README.md — this is a build-internal change; no user-facing usage/env/volume changes per the docs/dod.md "Documentation" criterion.
- Do NOT attempt `docker build` from inside the container — it has no Docker socket per CLAUDE.md. Image smoke is operator-side after merge.
</constraints>

<verification>
- `make precommit` must pass.
- `grep -E '^ARG ASTGREP_VERSION' Dockerfile` returns exactly one match.
- `grep '@ast-grep/cli' Dockerfile` returns exactly one match.
- `grep -c 'npm install -g' Dockerfile` returns exactly one (no second install line added).
- `grep -E '^## Unreleased' CHANGELOG.md` returns one match; `grep -A5 '^## Unreleased' CHANGELOG.md | grep -q '@ast-grep/cli'` succeeds.

Cannot run `docker build` inside the dark-factory container per CLAUDE.md. Post-merge smoke (operator-side):
```bash
docker build -t claude-yolo:test .
docker run --rm claude-yolo:test ast-grep --version
```
</verification>
