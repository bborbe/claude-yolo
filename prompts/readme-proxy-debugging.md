---
status: draft
created: "2026-04-16T16:32:03Z"
---

<summary>
- README explains how to watch tinyproxy activity from the host
- Users can troubleshoot blocked domains without reading source
- Documents the log file location and LogLevel setting
- Shows the exact docker command to tail the log
</summary>

<objective>
Add a short "Debugging the proxy" subsection to `README.md` under the existing "Network Firewall" section. Explain where tinyproxy writes its log, how to tail it from the host, and which LogLevel is used by default — so users can self-diagnose blocked domains.
</objective>

<context>
Read `CLAUDE.md` for project conventions.
Read `README.md` — find the "### Network Firewall" section (around line 211) and the bullet about "Adding domains".
Read `files/tinyproxy.conf` — note `LogLevel Connect` and `LogFile "/tmp/tinyproxy.log"`.
Read `scripts/yolo-run.sh` to confirm how the container is launched (container name is dynamic; users reference it via `docker ps`).
</context>

<requirements>
1. In `README.md`, inside the "### Network Firewall" section, after the "**Adding domains:**" line, append a new paragraph/subsection titled `**Debugging the proxy:**`.
2. The new subsection must cover:
   - Log file path inside the container: `/tmp/tinyproxy.log`
   - Default `LogLevel Connect` logs every CONNECT tunnel (domain + verdict)
   - Exact commands to view the log from the host:
     ```bash
     # Find the container
     docker ps

     # Tail live
     docker exec -it <container> tail -f /tmp/tinyproxy.log

     # Dump once
     docker exec <container> cat /tmp/tinyproxy.log
     ```
   - Brief note: if a domain appears `Denied` in the log, add a regex for it to `files/tinyproxy-allowlist` and rebuild.
3. Keep it concise — under 15 lines.
4. Do NOT change anything outside the "Network Firewall" section.
5. Run `make precommit` to verify.
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Do NOT edit `CHANGELOG.md` (this is a docs-only change — release notes handled separately).
- Preserve existing README formatting, headings, and bullet style.
</constraints>

<verification>
Run `make precommit` -- must pass.
</verification>
