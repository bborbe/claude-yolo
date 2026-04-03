---
status: completed
summary: Removed hardcoded Go module cache volume mount from yolo-run.sh and added CHANGELOG entry
container: claude-yolo-007-remove-hardcoded-go-pkg-mount
dark-factory-version: v0.94.1-dirty
created: "2026-04-03T14:17:55Z"
queued: "2026-04-03T14:17:55Z"
started: "2026-04-03T14:17:59Z"
completed: "2026-04-03T14:18:30Z"
---

<summary>
- Remove host Go module cache sharing from container startup
- Container downloads Go modules independently instead of sharing the host cache
- Hardcoded host path assumes Go is installed on host and breaks on non-Go machines
- Single line removal in the docker run volume mount block
- No other volume mounts affected
</summary>

<objective>
yolo-run.sh docker run command no longer mounts host Go module cache. Container downloads modules independently.
</objective>

<context>
- `scripts/yolo-run.sh` — host-side script that runs the container; line 65 has `-v "$HOME/go/pkg:/home/node/go/pkg"`
- This mount was added early when all usage was Go projects
- Container already has Go installed and can download modules itself
- Removing this makes claude-yolo work on machines without Go installed
</context>

<requirements>
1. In `scripts/yolo-run.sh`, remove the volume mount line:
   ```
   old: -v "$HOME/go/pkg:/home/node/go/pkg" \
   new: (delete line)
   ```
2. Update CHANGELOG.md — add entry under `## Unreleased` (create section above `## v0.5.1` if missing):
   ```
   - Remove hardcoded Go module cache volume mount from yolo-run.sh
   ```
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git
- Do NOT modify any other volume mounts in the docker run command
- Do NOT add replacement mount logic — container downloads modules independently
- Do NOT modify Dockerfile
</constraints>

<verification>
- `make precommit` passes
- `grep -c 'go/pkg' scripts/yolo-run.sh` returns 0
</verification>
