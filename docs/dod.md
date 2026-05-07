# Definition of Done

Review your changes against each criterion. Linting already ran via `validationCommand` — these are checks you perform by inspecting your work. Report any unmet criterion as a blocker.

## Shell scripts

- `shellcheck` clean (validationCommand enforces this)
- `set -euo pipefail` at the top of every script
- All variable expansions quoted (`"$var"`, not `$var`) unless splitting is intentional
- No `echo` debug output left behind

## Dockerfile

- Versions pinned for reproducibility (Go, Node base tag, updater, tinyproxy, etc.)
- New `RUN` steps don't leave caches/tmp behind (`apt clean`, `rm -rf /var/lib/apt/lists/*`)
- New tools installed in the right stage and owned by the non-root `node` user where possible

## Network sandbox

- New outbound host added to `files/tinyproxy-allowlist` if the change requires reaching it
- No bypass of the firewall (no direct egress that skips tinyproxy)

## Python (stream-formatter)

- Stdlib only — no pip dependencies
- Compatible with `python3 -m py_compile files/stream-formatter.py`

## Documentation

- README.md updated if usage, env vars, or volumes change
- CLAUDE.md updated if dark-factory workflow or architecture changes
- CHANGELOG.md has an entry under `## Unreleased`
- Renamed/removed env var, flag, or script arg → grep the repo and update all references
