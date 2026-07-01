---
status: verifying
tags:
    - dark-factory
    - spec
approved: "2026-07-01T09:59:33Z"
generating: "2026-07-01T09:59:34Z"
prompted: "2026-07-01T10:04:31Z"
verifying: "2026-07-01T10:07:18Z"
branch: dark-factory/bump-claude-code-2-1-197
---

## Summary

- Refresh the pinned `@anthropic-ai/claude-code` npm version baked into the claude-yolo container from `2.1.169` (frozen on 2026-06-27) to `2.1.197`.
- `2.1.169` was pinned after a Claude release introduced a marketplace-consent gate that broke headless `claude -p` plugin discovery — the same regression must not return.
- 28 patch releases later, `2.1.197` is upstream's current stable: Sonnet 5 default at 1M-token window, more reliable long-running background sessions, background-agent auto-resume, and 16 bug fixes.
- Change is intentionally minimal: `Dockerfile` ARG + surrounding pin-comment + CHANGELOG entry. Everything else — firewall, entrypoint, other ARGs, Node base — is out of scope.
- Load-bearing evidence is `dark-factory healthcheck` passing against a freshly-built image, because that probe matches the original regression signature.

## Problem

`@anthropic-ai/claude-code` is pinned at `2.1.169`, five months behind upstream stable. The pin was defensive — a specific upstream regression broke dark-factory's headless plugin-discovery path — but keeping it frozen indefinitely means the claude-yolo image ships without Sonnet 5, the 1M-token window, background-agent auto-resume, and 16 accumulated bug fixes. Every dark-factory container run and every `clauder` session pays that cost. The bump is only safe if we re-run the exact probe that motivated the original pin.

## Goal

The claude-yolo image, built from `master` after this change, ships `@anthropic-ai/claude-code@2.1.197`, still passes `dark-factory healthcheck` end-to-end, and documents `2.1.197` as the new known-good version alongside the same "bump deliberately, smoke-test first" protocol.

## Non-goals

- Do NOT bump the Node base tag (`FROM node:22`).
- Do NOT bump `GO_VERSION`, `UPDATER_VERSION`, or `ASTGREP_VERSION`.
- Do NOT publish the multi-arch image to Docker Hub — that is a separate manual `make build-multiarch` step per `docs/releasing-claude-yolo.md`.
- Do NOT cut a new claude-yolo release tag — `autoRelease: false` per `.dark-factory.yaml`; release is a separate flow.
- Do NOT touch `files/`, `scripts/`, or any surface outside `Dockerfile` + `CHANGELOG.md`.
- Do NOT parameterize or add tooling for future bumps — invariant; if bump ergonomics ever need automation, that is a separate spec.

## Acceptance Criteria

- [ ] `grep -n '^ARG CLAUDE_CODE_VERSION=2.1.197$' Dockerfile` prints line `13` — evidence: grep exit 0 with the expected line number.
- [ ] `grep -n '2\.1\.197' Dockerfile` returns at least one match inside the pin-comment block (lines 4–12) naming `2.1.197` as the new known-good version — evidence: grep output showing a hit in the 4–12 range.
- [ ] `grep -n '^ARG CLAUDE_CODE_VERSION=2.1.169$' Dockerfile` returns no match — evidence: grep exit 1 (no match).
- [ ] `grep -c '^ARG GO_VERSION=1.26.4$\|^ARG UPDATER_VERSION=0.23.2$\|^ARG ASTGREP_VERSION=latest$' Dockerfile` prints `3` — evidence: unchanged sibling ARGs.
- [ ] `CHANGELOG.md` contains a `## Unreleased` heading followed by a bullet naming both `2.1.169 → 2.1.197` and the dark-factory-healthcheck rationale — evidence: `grep -A5 '^## Unreleased$' CHANGELOG.md` shows the bullet.
- [ ] `git diff --name-only master` lists exactly `Dockerfile` and `CHANGELOG.md`, no other paths — evidence: two-line output.
- [ ] `make precommit` exits 0 — evidence: exit code.
- [ ] `make build` exits 0 and produces a single-arch image tagged locally — evidence: exit code + `docker image inspect` on the resulting tag exits 0.
- [ ] `scripts/yolo-run.sh /tmp/yolo-smoke-repo "echo hello"` exits 0 with `hello` on stdout — evidence: exit code + stdout capture.
- [ ] `dark-factory healthcheck` against the freshly built image reports all seven probes (docker, image, boot, claude, mount, gh, notifications) as pass — evidence: healthcheck exit 0 and stdout/log listing seven passing probes. This is the load-bearing regression check that reproduces the 2026-06-27 signature.

## Verification

Run in the repo root of the feature worktree, in order:

```
make precommit
make build
mkdir -p /tmp/yolo-smoke-repo && (cd /tmp/yolo-smoke-repo && [ -d .git ] || git init -q)
scripts/yolo-run.sh /tmp/yolo-smoke-repo "echo hello"
dark-factory healthcheck
```

Expected: every command exits 0; `scripts/yolo-run.sh` prints `hello`; `dark-factory healthcheck` reports seven probes pass (docker, image, boot, claude, mount, gh, notifications).

## Desired Behavior

1. `Dockerfile` line 13 pins `CLAUDE_CODE_VERSION=2.1.197`.
2. `Dockerfile` lines 4–12 (the pin-comment block) name `2.1.197` as the new known-good version verified against dark-factory's scenario suite; the "Bump deliberately: edit + tag a new claude-yolo release; smoke-test by running a dark-factory spec generation against the new image" protocol paragraph is preserved verbatim in intent (`2.1.169` may remain as historical context, e.g. "previously `2.1.169`", but is not required).
3. `CHANGELOG.md` gains a `## Unreleased` section (inserted above `## v0.12.0`) with a bullet that names the `2.1.169 → 2.1.197` transition and cites the dark-factory-healthcheck-pass rationale in one sentence.
4. No sibling `Dockerfile` ARG (`GO_VERSION`, `UPDATER_VERSION`, `ASTGREP_VERSION`) is touched.
5. No file outside `Dockerfile` and `CHANGELOG.md` is touched.
6. Post-bump image continues to satisfy `dark-factory healthcheck`, meaning the original `Unknown command: /dark-factory:generate-prompts-for-spec` regression does not recur.

## Constraints

- `Dockerfile` structure (FROM, ARG ordering, ENV, RUN stages) unchanged apart from the single ARG line and the surrounding comment.
- `files/tinyproxy-allowlist`, `files/entrypoint.sh`, `scripts/yolo-run.sh`, and every other file must remain byte-identical.
- Existing `make precommit` (shellcheck) must still pass.
- The "Bump deliberately … smoke-test" instruction inside the pin comment is a durable operator contract — its meaning must survive the edit.
- CHANGELOG convention per `docs/dod.md`: new entries go under `## Unreleased`.
- Release-gate requirements per `docs/releasing-claude-yolo.md` for build-surface changes are satisfied by the Verification block.

## Failure Modes

| Trigger | Detection | Expected behavior | Recovery | Reversibility |
|---|---|---|---|---|
| `2.1.197` reintroduces the marketplace-consent regression | `dark-factory healthcheck` fails on the `claude` probe with `Unknown command: /dark-factory:…` | Do not merge; keep pin at `2.1.169`; revert the Dockerfile+CHANGELOG diff | `git restore Dockerfile CHANGELOG.md`; re-run `make build` to rebuild `2.1.169` image | Fully reversible — no state migrated |
| `2.1.197` yanked or missing from npm at build time | `make build` fails at the `npm i -g @anthropic-ai/claude-code@2.1.197` step | Abort merge; either pick the next stable published version or hold at `2.1.169` | Update ARG to a known-published version; rerun verification | Fully reversible |
| Local Docker daemon unreachable during verification | `make build` fails before image layer creation | Fix daemon; do not skip the healthcheck probe | Restart Docker Desktop / daemon; rerun `make build` + `dark-factory healthcheck` | N/A — verification-time only |
| Partial edit lands (ARG bumped, comment not refreshed) | Post-edit grep of comment block shows only `2.1.169` and no `2.1.197` | Fail AC on the comment-refresh check before running `make build` | Re-edit the comment block; re-run grep | Fully reversible |
| Operator forgets to run `dark-factory healthcheck` | CI has no healthcheck stage — only human gate catches it | Block PR merge until the healthcheck evidence is attached to the PR body | Attach `dark-factory healthcheck` transcript to PR before merge | N/A — process gate |

## Security / Abuse Cases

Not applicable in the classical sense — no new input, HTTP path, file surface, or trust boundary is added. The only supply-chain surface is the pinned `@anthropic-ai/claude-code@2.1.197` tarball itself; that is inherent to any Claude Code bump and is the reason we require `dark-factory healthcheck` (a live probe) rather than trusting version metadata alone.

## Do-Nothing Option

Keep pin at `2.1.169`. Cost: claude-yolo containers continue to run a five-month-old Claude Code without Sonnet 5, the 1M-token window, background-agent auto-resume, and 16 accumulated bug fixes. Every dark-factory spec-gen run and every `clauder` session pays that cost every day. Acceptable only if a bump attempt at `2.1.197` reproduces the original regression under `dark-factory healthcheck` — then holding is the correct answer until a later upstream release is proven clean.
