# Releasing claude-yolo

How to ship a new version of the claude-yolo Docker image. Read before approving any prompt that touches the build surface.

## One surface

claude-yolo ships a single artifact:

| Surface | Versioned by | Consumed by | Bumped how |
|---------|--------------|-------------|------------|
| **Docker image** `bborbe/claude-yolo:vX.Y.Z` + `:latest` | git tag `vX.Y.Z` + matching `## vX.Y.Z` section in `CHANGELOG.md` | `scripts/yolo-run.sh` on the host (pulls `:latest`) | Auto-tagged by dark-factory's daemon (`autoRelease: true` in `.dark-factory.yaml`) when a prompt updates `## Unreleased` |

There is no Go binary, no plugin, no marketplace. CHANGELOG and tag are the only sources of truth.

## The release gate (run BEFORE approving any prompt that touches the build)

`make precommit` only runs shellcheck. It does NOT exercise the Dockerfile, firewall rules, tinyproxy allowlist, entrypoint, or stream-formatter. Those break at runtime, not lint time. The gate exists to catch that gap.

The rule: **before approving a prompt that may change runtime behavior, build a fresh image and run it end-to-end**.

```bash
# 1. Lint
make precommit

# 2. Build a fresh local image (single-arch is fine for the gate)
make build

# 3. Smoke-run the container against a throwaway repo
scripts/yolo-run.sh /tmp/some-git-repo "echo hello"
# Expected: container starts, firewall init succeeds, Claude Code runs, exits clean
```

If any step fails: do **not** approve the prompt. Fix the regression first.

### Build surface — what counts

A diff touches the build surface if it changes any of:

- `Dockerfile`
- `files/` (entrypoint, firewall, tinyproxy config, allowlist, stream-formatter)
- `scripts/yolo-run.sh`, `scripts/yolo-prompt.sh`
- `Makefile`

Pure CHANGELOG/docs/prompt edits don't need the gate.

### When the diff is empty

If `git diff <last-tag>..HEAD --name-only` shows nothing on the build surface, skip the gate. This is the only documented skip — don't invent others.

## Version alignment check (run BEFORE every release commit)

```bash
LATEST_TAG=$(git tag -l | sort -V | tail -1)
LATEST_CHANGELOG=$(grep -m1 '^## v' CHANGELOG.md | sed 's/^## //')
test "$LATEST_TAG" = "$LATEST_CHANGELOG" && echo "OK aligned" || echo "MISMATCH tag=$LATEST_TAG changelog=$LATEST_CHANGELOG"
```

After auto-release, the latest tag and the top `## vX.Y.Z` section must match.

## Auto-release (dark-factory owns the tag)

`.dark-factory.yaml` has `autoRelease: true`. Every successful prompt that updates `## Unreleased` triggers:

1. Stage all changes (including the agent's `## Unreleased` entry)
2. Determine bump (patch/minor) from changelog content
3. Rename `## Unreleased` → `## vX.Y.Z`
4. Commit `release vX.Y.Z`
5. Tag `vX.Y.Z`, push tag and commit
6. Move the prompt file to `prompts/completed/` and push that commit too

The operator's responsibility is **running the gate before approving the prompt**. Once approved, the daemon ships whatever the agent produced.

To verify a release shipped to git:

```bash
git fetch --tags
git describe --tags --abbrev=0           # latest tag, e.g. v0.6.2
git log "$(git describe --tags --abbrev=0)"..HEAD --oneline   # any unpushed commits beyond it
```

After successful auto-release: clean `git status`, zero `git rev-list @{u}..HEAD --count`.

## Publish to Docker Hub (manual, after auto-tag)

Auto-release tags git but does NOT push the image. The operator publishes:

```bash
# Multi-arch is the canonical publish path (linux/amd64 + linux/arm64)
make build-multiarch
```

`build-multiarch` builds and pushes both architectures in one step (uses `docker buildx --push`). The resulting tags on Docker Hub:

- `bborbe/claude-yolo:vX.Y.Z` (the new tag, matches the git tag without the `v`-stripping — full `vX.Y.Z`)
- `bborbe/claude-yolo:latest` (moved to point at the new release)

`VERSION` is computed by the Makefile from `git describe --tags`, so run `make build-multiarch` from a clean checkout sitting on the new tag — otherwise the image picks up `-dirty` or a stale describe.

### Single-arch (local testing only)

`make build` produces a single-arch local image with the correct tags but does NOT push. Use it for the release gate. Do not use it as the publish path — host architecture is whatever the operator's machine happens to be.

## Verify the release

```bash
docker pull bborbe/claude-yolo:latest
docker run --rm bborbe/claude-yolo:latest --version 2>/dev/null || docker inspect bborbe/claude-yolo:latest | grep -i 'created\|RepoTags'
scripts/yolo-run.sh /tmp/some-git-repo "echo hello"
```

The container should start, firewall init should succeed, and the prompt should execute against the new image.

## Common mistakes

- **Approving a prompt before running the gate.** `make precommit` passes while runtime is broken (firewall rule typo, Dockerfile syntax, allowlist regression).
- **Forgetting `make build-multiarch` after auto-tag.** Git tag advances, Docker Hub stays on the previous version. Hosts that pull `:latest` see no change.
- **Running `make build-multiarch` from a dirty tree or off the tag.** `VERSION` ends up as `vX.Y.Z-N-gSHA-dirty` and the published tag doesn't match the git tag.
- **Editing `CHANGELOG.md` `## vX.Y.Z` sections after auto-release.** The tag is immutable; the section should be too. New changes go in a new `## Unreleased`.

## See also

- `CLAUDE.md` — dark-factory workflow rules
- `.dark-factory.yaml` — `autoRelease` + workflow config
- `Makefile` — `build`, `build-multiarch`, `upload`, `buca` targets
