<objective>
Add trivy's required endpoints to the firewall allowlist in `files/init-firewall.sh` so that `trivy` can download its vulnerability database during `make precommit` inside the YOLO container.

Currently trivy fails with "no route to host" because the container firewall blocks its DB download endpoints.
</objective>

<context>
Go CLI project for managing an isolated Docker container with iptables firewall.
Read CLAUDE.md for project conventions.

The firewall allowlist works by resolving domain names to IPs at startup and adding them to an ipset called `allowed-domains`.

Key file: `./files/init-firewall.sh`

Look at how existing domains are added (e.g. proxy.golang.org, storage.googleapis.com) to understand the pattern — then add trivy's required domains using the same pattern.

Trivy downloads its vulnerability DB from:
- `ghcr.io` — GitHub Container Registry (trivy DB images)
- `pkg-containers.githubusercontent.com` — GitHub package CDN
- `api.github.com` — already allowed (GitHub ranges)
</context>

<requirements>
1. Identify the section in `init-firewall.sh` where domains are resolved and added to the allowlist
2. Add `ghcr.io` to the resolved domains list
3. Add `pkg-containers.githubusercontent.com` to the resolved domains list
4. Verify the pattern matches existing domain entries exactly
</requirements>

<output>
Modify in place:
- `./files/init-firewall.sh`
</output>

<verification>
After changes, rebuild the container and run a precommit check:
```bash
make build
~/Documents/workspaces/claude-yolo/scripts/yolo-prompt.sh <any-project> <any-prompt>
```

Confirm trivy no longer shows "no route to host" errors.
</verification>

<success_criteria>
- `ghcr.io` and `pkg-containers.githubusercontent.com` added to domain allowlist
- Pattern matches existing domain entries in the script
- No syntax errors in the shell script
</success_criteria>
