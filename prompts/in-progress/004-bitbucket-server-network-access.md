---
status: approved
created: "2026-03-10T11:55:45Z"
queued: "2026-03-10T11:55:45Z"
---

<summary>
- Private Go modules hosted on Bitbucket Server can be resolved during container builds
- Outbound HTTPS traffic to the internal Bitbucket Server is permitted through the proxy
- Outbound git traffic on port 7999 (Bitbucket Server's non-standard SSH port) is permitted through the firewall
- Projects with internal dependencies no longer fail during dependency verification
</summary>

<objective>
Allow the YOLO container to access `bitbucket.seibert.tools` over HTTPS (port 443 via proxy) and SSH/git (port 7999 direct). Currently, projects with private Go modules on Bitbucket Server fail during `go mod tidy` / `go mod verify` because the domain is blocked by the proxy allowlist and the non-standard SSH port is blocked by iptables.
</objective>

<context>
Read CLAUDE.md for project conventions.
Read `files/tinyproxy-allowlist` — regex-based domain allowlist for tinyproxy proxy.
Read `files/tinyproxy.conf` — proxy config, currently allows ConnectPort 443 and 80 only.
Read `files/init-firewall.sh` — iptables rules. Two layers control outbound access: tinyproxy (HTTPS domain filtering) and iptables (port-level firewall). Both must allow the new destination.
</context>

<requirements>
1. Add `^bitbucket\.seibert\.tools$` to `files/tinyproxy-allowlist` (append after existing entries)

2. Add `ConnectPort 7999` to `files/tinyproxy.conf` (after existing ConnectPort lines)

3. Add iptables rule to `files/init-firewall.sh` to allow outbound TCP port 7999:
   ```bash
   # Allow SSH to Bitbucket Server (non-standard port)
   iptables -A OUTPUT -p tcp --dport 7999 -j ACCEPT
   ```
   Add this immediately after the `# Allow SSH to GitHub (git push/pull over SSH)` block.
</requirements>

<constraints>
- Do NOT remove or modify any existing allowlist entries
- Do NOT remove or modify existing firewall rules
- Do NOT change the default deny policy
- Do NOT add broad wildcards — only the specific domain
- Do NOT commit — dark-factory handles git
</constraints>

<verification>
```
make precommit
```
Must pass. Also verify by inspection:
- `grep seibert files/tinyproxy-allowlist` shows the new entry
- `grep 7999 files/tinyproxy.conf` shows ConnectPort 7999
- `grep 7999 files/init-firewall.sh` shows the iptables rule
</verification>
