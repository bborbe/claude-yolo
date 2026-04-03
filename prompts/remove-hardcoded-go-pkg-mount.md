---
status: draft
---

## Goal

Remove the hardcoded `$HOME/go/pkg` Docker volume mount from `scripts/yolo-run.sh`. Go module cache mounting is now handled per-project via `extraMounts` in `.dark-factory.yaml`.

## Changes

In `scripts/yolo-run.sh`, remove this line from the `docker run` command:

```
    -v "$HOME/go/pkg:/home/node/go/pkg" \
```

Keep all other volume mounts unchanged.

## Verification

- `make precommit` passes
- The `docker run` command in `yolo-run.sh` no longer references `go/pkg`
