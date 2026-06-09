# Network firewall

How outbound traffic is restricted inside the YOLO container. Read before adding a new allowed domain, debugging a blocked request, or changing `files/init-firewall.sh`.

## Architecture

Two layers, enforced together — fail one, fail closed:

| Layer | Runs as | Enforces | File |
|---|---|---|---|
| **tinyproxy** | `root` | Domain-based allowlist (regex), CONNECT-only on 443/80/7999 | `files/tinyproxy.conf`, `files/tinyproxy-allowlist` |
| **iptables** | kernel | Only `root` (tinyproxy) can egress directly; all other UIDs (`node` = Claude) must go through proxy | `files/init-firewall.sh` |

The two are required together. iptables alone would allow any domain through tinyproxy. tinyproxy alone could be bypassed by Claude making direct outbound. Together: Claude can only reach domains the allowlist matches.

## Request flow

```
Claude ('node' user, non-root — UID is remapped at container start to match the host workspace owner, see files/entrypoint.sh)
   ↓ HTTPS_PROXY=http://127.0.0.1:8888
tinyproxy (UID 0 'root', port 8888)
   ↓ checks allowlist → if no match: 403
   ↓ if match: CONNECT to remote
iptables OUTPUT chain
   ↓ owner --uid-owner 0 → ACCEPT  (root only)
   ↓ anything else → REJECT (icmp-admin-prohibited)
internet
```

`HTTP_PROXY`/`HTTPS_PROXY` (and lowercase `http_proxy`/`https_proxy` for tools like older curl / pip that only honor the lowercase form) are set in `files/entrypoint.sh`. Tools that honor those env vars (curl, git, go, npm, pip, claude) automatically route through tinyproxy. Tools that don't (a hand-rolled TCP client) hit the iptables REJECT and fail.

## The iptables rules (in order)

From `files/init-firewall.sh`:

1. `INPUT/OUTPUT -i/-o lo ACCEPT` — localhost (so Claude can reach tinyproxy on 127.0.0.1:8888)
2. `INPUT/OUTPUT -m state ESTABLISHED,RELATED ACCEPT` — return packets for existing connections
3. `OUTPUT udp/53 --uid-owner 0 ACCEPT` — DNS query, root only (so tinyproxy can resolve)
4. `INPUT udp --sport 53 ACCEPT` — DNS reply return path
5. `OUTPUT --uid-owner 0 ACCEPT` — root full outbound (tinyproxy → remote)
6. `OUTPUT tcp --dport 22 ACCEPT` — SSH (GitHub via SSH). **Note: any UID, including `node` / Claude — not scoped to root**, by design (see threat-model note below)
7. `OUTPUT tcp --dport 7999 ACCEPT` — Bitbucket Server SSH. Same UID-unscoped intent as rule 6
8. `INPUT/OUTPUT host-network ACCEPT` — Docker bridge (volume mounts, hostname resolution)
9. Policy: `INPUT/FORWARD/OUTPUT DROP` + explicit `REJECT` with `icmp-admin-prohibited` on tail OUTPUT

Notably: **SSH on 22 / 7999 bypasses tinyproxy** by design — git push/pull over SSH would otherwise not work, and proxying SSH through an HTTP proxy is awkward. The trade-off: Claude could SSH to an arbitrary host on 22/7999. The threat model accepts this because the container has no SSH keys mounted by default.

## Adding a domain

Edit `files/tinyproxy-allowlist`. One regex per line. Patterns are anchored — use `^` and `$`.

```
^api\.example\.com$           # exact host
^.*\.example\.com$            # any subdomain (note: also matches example.com? no — needs the leading dot)
^.*\.example\.com$|^example\.com$   # OR for apex + subdomains
```

Then rebuild: `make build`. The allowlist is baked into the image at build time. Live edits inside a running container won't take effect.

**Verify the addition** end-to-end with a smoke test:

```bash
make build
scripts/yolo-run.sh /tmp/some-repo "curl -sS https://api.example.com/path && echo OK || echo BLOCKED"
```

If you get `BLOCKED`, look at the proxy log inside a running container: `docker exec <container> tail -50 /tmp/tinyproxy.log`. The log shows `Connect (file): host.example.com` for matches and `Filtered request from <ip>: host.example.com` for rejections.

## Allowed-by-default domains

`files/tinyproxy-allowlist` is the authoritative source — table below is a categorized snapshot and may drift; check the file when in doubt:

| Category | Domains |
|---|---|
| GitHub | `*.github.com`, `*.githubusercontent.com`, `github.com`, `ghcr.io`, `pkg-containers.githubusercontent.com` |
| Anthropic / Claude | `api.anthropic.com`, `console.anthropic.com`, `platform.claude.com`, `claude.ai`, `statsig.anthropic.com` |
| Alternative providers | `api.minimax.io` (Anthropic-compatible — set `ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic`) |
| Go modules | `proxy.golang.org`, `sum.golang.org`, `go.dev`, `vuln.go.dev` |
| npm | `registry.npmjs.org` |
| Python | `pypi.org`, `files.pythonhosted.org`, `www.python.org` |
| Alpine (Docker base) | `dl-cdn.alpinelinux.org` |
| OSV (vulnerability DB) | `api.osv.dev` |
| Observability | `sentry.io`, `statsig.com`, `storage.googleapis.com` |
| VS Code (extensions / updates) | `marketplace.visualstudio.com`, `update.code.visualstudio.com`, `vscode.blob.core.windows.net` |
| Internal | `bitbucket.seibert.tools` |

## Verifying the firewall at container start

`files/init-firewall.sh` performs two self-checks at the end:

1. **Negative**: `curl https://example.com` through the proxy must fail. If it succeeds, the allowlist is broken open → exit 1.
2. **Positive**: `curl https://api.github.com/zen` through the proxy must succeed. If it fails, the firewall blocked something it shouldn't → exit 1.

Either failure aborts container startup. The firewall script itself always runs; what `DEBUG=1` controls is whether the entrypoint (`files/entrypoint.sh:20-23`) redirects all firewall-init output to `/dev/null`. Set `DEBUG=1` to see the init output for diagnostics.

## Threat model

- ✅ Claude cannot exfiltrate to arbitrary domains — tinyproxy filters
- ✅ Claude cannot bypass tinyproxy with a hand-rolled TCP client — iptables blocks non-root egress
- ✅ Claude cannot bind a server inside the container reachable from outside — Docker default
- ⚠️ Claude can reach any host on TCP 22/7999 (SSH bypass) — by design; container has no SSH keys
- ⚠️ Claude can reach `bitbucket.seibert.tools` (private/internal) — by allowlist intent for project-internal git
- ❌ Claude cannot read `/var/run/docker.sock` (none mounted) → no Docker-in-Docker
- ❌ Claude cannot access kubectl contexts (none mounted)

## Related

- `files/entrypoint.sh` — sets `HTTP_PROXY` / `HTTPS_PROXY` env vars
- `docs/dod.md#network-sandbox` — review gate: new outbound host must be in the allowlist
- `docs/troubleshooting.md` — common firewall failures (proxy timeout, DNS, blocked domain)
