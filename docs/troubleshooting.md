# Troubleshooting

Common YOLO container failures and how to recover. Symptoms first; root-cause + fix follow each row.

## Container won't start

| Symptom | Root cause | Fix |
|---|---|---|
| `ERROR: YOLO already running in <git-root>` | A previous run wrote `.yolo-lock` and the container is still alive | `docker kill <container-id from lock file>` — the script prints the kill command in the error |
| `Removing stale lock file` then proceeds | Previous container died without cleaning up `.yolo-lock` | No action — script auto-recovers |
| `ERROR: Not in a git repository: <path>` | `yolo-run.sh` requires git-root detection to mount `/workspace` | `cd` to a git repo, or pass a path that is one |
| `permission denied while trying to connect to the Docker daemon socket` | Host docker daemon down or current user not in `docker` group | `docker info` to verify; on Linux `sudo usermod -aG docker $USER` + re-login |
| Container starts then exits immediately with `ERROR: tinyproxy failed to start` | iptables / NET_ADMIN missing | Verify `--cap-add=NET_ADMIN --cap-add=NET_RAW` in `docker run` (the helper script sets these — only matters if running raw `docker run`) |
| `ERROR: Firewall verification failed - reached https://example.com` | Allowlist file got corrupted or default-deny is off | Inspect `files/tinyproxy-allowlist` + `files/tinyproxy.conf` (`FilterDefaultDeny Yes` must be present); rebuild |
| `ERROR: Firewall verification failed - cannot reach https://api.github.com` | DNS broken inside container, or iptables rules dropped traffic before tinyproxy | `DEBUG=1` env to unmute firewall init; check `iptables -L -v` inside the container; usually a missing `host-network` route |

## yolo-lock cleanup

`.yolo-lock` lives at the git root (the mounted `/workspace`). It contains the container ID. The script's trap (`scripts/yolo-run.sh:141`) removes it on EXIT/INT/TERM — but a `kill -9`, host crash, or docker daemon restart can orphan it.

Manual cleanup:

```bash
cat /path/to/repo/.yolo-lock                                # see container ID
docker inspect <id> >/dev/null 2>&1 && docker kill <id>     # only kill if alive
rm /path/to/repo/.yolo-lock
```

Or the lazy form — just re-run `yolo-run.sh`; if the container is dead it auto-removes the stale lock.

## Network failures

| Symptom | Likely cause | First check |
|---|---|---|
| `curl: (28) Failed to connect within timeout` from Claude | Domain not in allowlist OR proxy down | `docker exec <id> tail -50 /tmp/tinyproxy.log` — look for `Filtered request from ... : <host>` |
| `curl: (6) Could not resolve host` | DNS broken (Docker DNS rule got flushed) | `docker exec <id> nslookup github.com` — should resolve via 127.0.0.11 |
| `git clone` over SSH hangs | SSH not bypassing tinyproxy correctly | iptables rule `OUTPUT -p tcp --dport 22 ACCEPT` must be present — `docker exec <id> iptables -L OUTPUT -n` |
| `403 Forbidden` from tinyproxy | Allowlist regex didn't match the host | Check regex anchoring: `^api\.example\.com$` does NOT match `api.example.com.evil.com` — that's the point. But a typo like missing `\.` will also miss legitimate hosts |
| `npm install` blocked | `registry.npmjs.org` in allowlist but `cdn.jsdelivr.net` (or another transitive CDN) is not | Add the CDN to allowlist + rebuild |

**See:** `docs/network-firewall.md` for the full request-flow + allowlist semantics.

## Attach / detach issues

`docker attach <id>` is how `yolo-run.sh` connects you to the interactive session. Gotchas:

| Symptom | Cause | Fix |
|---|---|---|
| Ctrl+C kills the container instead of cancelling current command | `attach` forwards signals by default | Detach with **Ctrl+P Ctrl+Q** (printed by the script), don't Ctrl+C |
| Typing does nothing inside the session | TTY not allocated | Confirm `docker run -dit` — interactive (`-i`) + TTY (`-t`) + detached (`-d`); the helper script does this, only matters for raw runs |
| Terminal looks garbled after detach | Stale TTY state | `reset` in your host shell |
| Lost the container ID | Helper script printed it on launch; also: | `docker ps --filter ancestor=bborbe/claude-yolo:latest` |

## One-shot mode hangs

`yolo-run.sh <path> "<prompt>"` follows logs and waits for the container. If it hangs:

| Symptom | Likely cause | Fix |
|---|---|---|
| Logs flow but never exits | Claude is still working — stream-json hasn't sent `done` event | Wait, or `docker ps` to confirm container is still running |
| Logs stop, no exit | Claude crashed silently | `docker inspect <id> --format '{{.State.ExitCode}}'`; non-zero → bug. Re-run with `YOLO_OUTPUT=json` for raw stream-json |
| `claude --print` mode produces no output | Anthropic API auth missing | Confirm `ANTHROPIC_AUTH_TOKEN` is set on the host before invoking; helper forwards it via `-e ANTHROPIC_AUTH_TOKEN`. Note: the official Anthropic CLI also accepts `ANTHROPIC_API_KEY`, but this helper does NOT forward that variant — only `ANTHROPIC_AUTH_TOKEN`. If your shell has `ANTHROPIC_API_KEY` set, rename it or also export `ANTHROPIC_AUTH_TOKEN` |

## Build failures

`make build` builds the Docker image. Common failures:

| Symptom | Cause | Fix |
|---|---|---|
| `failed to fetch metadata: api.snapcraft.io` (or other) | A `RUN` step needs a domain not in the build-time allowlist | Build is on the host — host network, not the in-container firewall. Check host connectivity / VPN |
| `dial tcp: lookup proxy.golang.org: no such host` mid-build | Host DNS issue or Go toolchain version mismatch | Bump `Go` ARG in the Dockerfile to a version compatible with `go.dev` proxy availability |
| Image builds but container immediately exits | Entrypoint script error | `docker logs <id>` — look at the first 20 lines, usually a missing var or `chown` failure |

## Container leaks (multiple YOLO instances)

Each invocation of `yolo-run.sh` is supposed to be one container. If you see multiple:

```bash
docker ps --filter ancestor=bborbe/claude-yolo:latest --format 'table {{.ID}}\t{{.RunningFor}}\t{{.Names}}'
```

**Per-workspace cleanup (preferred — bounded blast radius):**

```bash
cd /path/to/workspace
docker kill "$(cat .yolo-lock)" 2>/dev/null && rm .yolo-lock
```

**Kill ALL running YOLO containers on the host (blast radius warning):**

```bash
# ⚠️ Kills every YOLO session on this host, not just orphans.
# A developer with parallel YOLO sessions across workspaces loses all of them.
# Prefer the per-workspace recipe above. Use this only when no active session exists.
docker ps --filter ancestor=bborbe/claude-yolo:latest -q | xargs -r docker kill
```

Then sweep `.yolo-lock` files: `find ~/Documents/workspaces -name .yolo-lock -delete` (or narrower).

## When all else fails

1. `docker logs -f <container-id>` — full container output
2. `docker exec <container-id> /bin/bash` — open a shell in a (suspected) running container; inspect `/tmp/tinyproxy.log`, `iptables -L -v`, `env`
3. `DEBUG=1 ./scripts/yolo-run.sh ...` — unmutes firewall-init output (see `docs/network-firewall.md` → "Verifying the firewall at container start" for the mechanism: `files/entrypoint.sh:20-23` redirects to `/dev/null` unless `DEBUG=1`)
4. Rebuild from scratch: `docker rmi bborbe/claude-yolo:latest && make build`

## Related

- `docs/network-firewall.md` — firewall architecture
- `docs/yolo-run.md` — script reference
- `docs/yolo-prompt.md` — prompt-execution reference
- `docs/dod.md` — review gate
