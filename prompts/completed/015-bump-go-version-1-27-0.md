---
status: completed
summary: 'Bumped GO_VERSION from 1.26.6 to 1.27.0 in Dockerfile and added the corresponding entry under ## Unreleased in CHANGELOG.md'
execution_id: claude-yolo-exec-015-bump-go-version-1-27-0
dark-factory-version: dev
created: "2026-08-19T20:20:00Z"
queued: "2026-08-19T18:46:28Z"
started: "2026-08-19T18:46:32Z"
completed: "2026-08-19T18:47:11Z"
---

<summary>
- The container image's Go toolchain is pinned to 1.27.0 (was 1.26.6)
- Image builds pull the Go 1.27.0 release from go.dev
- `go generate` mocks and `go.mod` toolchain directives stay in step with the fleet's Go version
- A new `## Unreleased` changelog section records the bump as a fix
- No other Dockerfile ARGs, build steps, or files are touched
- `make precommit` passes unchanged
</summary>

<objective>
Update the `GO_VERSION` build arg in `Dockerfile` from `1.26.6` to `1.27.0` so the container ships with the latest Go release, and record the change in the changelog.
</objective>

<context>
Read `CLAUDE.md` for project conventions.
Read `Dockerfile` — `GO_VERSION` is declared as an `ARG` near the top (around line 14) and consumed later by the Go install step.
Read `CHANGELOG.md` — entries go under `## Unreleased` at the top.
Read `docs/releasing-claude-yolo.md` — this change touches the Dockerfile build surface, so the release gate (build + smoke-run a fresh image) applies before approval.
</context>

<requirements>
1. In `Dockerfile`, change `ARG GO_VERSION=1.26.6` to `ARG GO_VERSION=1.27.0`.
2. Add an entry under `## Unreleased` in `CHANGELOG.md`:
   - `- fix: bump `GO_VERSION` from `1.26.6` to `1.27.0` (Go minor release). Keeps the image toolchain in step with the fleet so `go generate` mocks and `go.mod` toolchain directives don't mismatch inside dark-factory containers.`
   - If `## Unreleased` does not exist, create it as the first version section after the header preamble.
3. Do NOT change anything else in `Dockerfile` (no other ARGs, no RUN steps).
4. Do NOT change unrelated files.
5. Run `make precommit` to verify.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles the git commit; the release tag and image publish are owned by github-releaser (`.dark-factory.yaml` sets `autoRelease: false`).
- Do NOT edit `.dark-factory.yaml`, `Makefile`, or any script.
- Preserve existing Dockerfile formatting and ARG ordering.
</constraints>

<verification>
Run `make precommit` — must pass.
`grep '^ARG GO_VERSION=' Dockerfile` must output exactly `ARG GO_VERSION=1.27.0`.
`head -20 CHANGELOG.md` must show a `## Unreleased` section containing the Go bump entry.
</verification>
