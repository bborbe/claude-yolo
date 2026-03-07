---
status: completed
summary: Pinned updater installation in Dockerfile to v0.15.1
container: claude-yolo-003-pin-updater-version
dark-factory-version: v0.21.1
created: "2026-03-07T12:06:18Z"
queued: "2026-03-07T13:01:50Z"
started: "2026-03-07T13:02:56Z"
completed: "2026-03-07T13:03:21Z"
---
<objective>
Pin the bborbe/updater installation in the Dockerfile to a fixed version tag (v0.15.1) instead of the default branch.
</objective>

<context>
Read CLAUDE.md for project conventions.
Read Dockerfile before changing it.

Currently line 95 installs updater without a version:
  RUN /home/node/.local/bin/uv tool install git+https://github.com/bborbe/updater

This makes it unclear which updater version is included in the image and makes builds non-reproducible.
</context>

<requirements>
1. Change the updater install command to pin to tag v0.15.1:
   RUN /home/node/.local/bin/uv tool install git+https://github.com/bborbe/updater@v0.15.1
</requirements>

<constraints>
- Only change the updater install line, nothing else
</constraints>

<verification>
Verify the change was applied:
```bash
grep 'updater@v0.15.1' Dockerfile
```
Expected: line containing `git+https://github.com/bborbe/updater@v0.15.1`
</verification>
