# Changelog

All notable changes to this project will be documented in this file.

Please choose versions by [Semantic Versioning](http://semver.org/).

* MAJOR version when you make incompatible API changes,
* MINOR version when you add functionality in a backwards-compatible manner, and
* PATCH version when you make backwards-compatible bug fixes.

## v0.5.0

- feat: Make Claude config directory configurable via CLAUDE_YOLO_DIR env var (defaults to ~/.claude-yolo)

## v0.4.3

- Fix multi-arch build by creating `/home/node/.cache` directory before switching to node user

## v0.4.2

- Pass prompt via stdin file redirect instead of shell variable interpolation to avoid quoting issues with special characters

## v0.4.1

- Skip UID remapping when workspace owner is root (fixes Docker Desktop for Mac)
- Add buildkit inline cache to multi-arch build

## v0.4.0

- Add runtime UID remapping via `/etc/passwd` edit to match host workspace owner
- Replace `sudo` with `setpriv` for dropping privileges (fixes TTY passthrough for interactive mode)
- Run entrypoint as root, drop to remapped `node` user via `setpriv --reuid/--regid`
- Remove Go build cache from image to reduce size and avoid slow chown at startup
- Replace `gosu` dependency with `setpriv` (built-in `util-linux`)

## v0.3.2

- Add multi-arch build support (linux/amd64 + linux/arm64) via docker buildx

## v0.3.1

- Update updater tool from v0.15.1 to v0.17.23
- Consolidate all ARG declarations at top of Dockerfile

## v0.3.0

- feat: add `[HH:MM:SS]` timestamp prefix to all stream-formatter output lines

## v0.2.9

- Merge custom `.gitconfig-extra` into container gitconfig if mounted

## v0.2.8

- Allow `bitbucket.seibert.tools` over HTTPS (proxy allowlist) and SSH/git port 7999 (tinyproxy ConnectPort + iptables)

## v0.2.7

- Add `safe.directory` config to prevent VCS status error in entrypoint

## v0.2.6

- Pin updater tool to fixed version (v0.15.1) in Dockerfile

## v0.2.5

- Update Go version from 1.26.0 to 1.26.1 in Dockerfile
- Remove CLAUDE.md from git tracking
- Rename updater pin prompt (remove number prefix)

## v0.2.4

- Add prompt to pin updater to fixed version (v0.15.1) in Dockerfile

## v0.2.3

- Move specs directory structure

## v0.2.2

- Allow `go.dev`, `dl-cdn.alpinelinux.org`, and `www.python.org` in tinyproxy firewall

## v0.2.1

- Allow `pypi.org` and `files.pythonhosted.org` in tinyproxy firewall for Python projects

## v0.2.0

- Add `YOLO_OUTPUT` env var: set to `print` for raw text output via `claude --print` (default: stream-json + formatter)

## v0.1.2

- Add `uv` package manager and `bborbe/updater` tool to Docker image

## v0.1.1

- Add dark-factory config and prompt directories
- Fix completed prompt format to use YAML frontmatter

## v0.1.0

- Add configurable model via `YOLO_MODEL` env var (default: `sonnet`, auto-resolves to latest)
- Update default model from `claude-sonnet-4-5` to `sonnet` (no more version pinning)

## v0.0.9

- Reformat CHANGELOG.md to follow Changelog Writing Guide (flat list, proper SemVer preamble, remove `### Added/Fixed/Changed` subsections)
- Sort tinyproxy-allowlist entries alphabetically

## v0.0.8

- Replace IP-based firewall (ipset/dig/aggregate) with tinyproxy domain-based filtering
- Simplify init-firewall.sh: remove DNS resolution at startup
- Remove `ipset`, `dnsutils`, `aggregate` from container image
- Fix CDN-backed domains (api.osv.dev, storage.googleapis.com) breaking due to IP rotation after container init
- Add domain allowlist at `/etc/tinyproxy/allowlist` for easy domain management
- Add HTTP_PROXY/HTTPS_PROXY env vars set automatically in entrypoint

## v0.0.7

- Add `YOLO_PROMPT_FILE` env var to read prompt from mounted file (avoids shell escaping issues with `-e` flag)

## v0.0.6

- Fix bare key access in stream-formatter.py with `.get()` to prevent crash on malformed JSON
- Fix `git -C` replaced with `cd && git` in yolo-run.sh
- Fix README Configuration section to match actual Makefile variables
- Add missing yolo-prompt.sh usage documentation to README
- Add stream-formatter.py to project structure in README
- Wrap stream-formatter.py in `main()` with `__name__` guard for testability

## v0.0.5

- Fix bare key access in stream-formatter.py with `.get()` to prevent crash on malformed JSON
- Fix `git -C` replaced with `cd && git` in yolo-run.sh
- Wrap stream-formatter.py in `main()` with `__name__` guard for testability

## v0.0.4

- Fix missing `ghcr.io` and `pkg-containers.githubusercontent.com` in firewall allowlist so trivy can download vulnerability database during `make precommit`

## v0.0.3

- Fix lock file not cleaned up on exit due to trap aborting on dead container
- Fix trap quoting so `$LOCK_FILE` expands correctly
- Fix `git -C` replaced with `cd && git` in yolo-prompt.sh

## v0.0.2

- Add auto-detect version from git tags for docker image tagging
- Update `make build` to tag both versioned and `:latest` images
- Update `make upload` to push both versioned and `:latest` tags

## v0.0.1

- Add one-shot mode: pass prompt as argument to `yolo-run.sh` for automated execution
- Add `YOLO_PROMPT` environment variable support in entrypoint for prompt passthrough
- Add comprehensive README examples for both interactive and one-shot modes
- Add streaming logs to `.logs/yolo-YYYY-MM-DD-HH-MM-SS.log` with real-time output
- Add auto-gitignore `.logs/` directory in target workspace
- Add distribution setup with `~/.claude-yolo` configuration directory
- Add sample CLAUDE.md workflow configuration in `examples/`
- Add slash commands (`create-prompt.md`, `run-prompt.md`) in `commands/`
- Add `yolo-prompt.sh` helper script for executing prompts by number
- Add CI workflow with shellcheck validation (`make test`)
- Add Claude Code workflow for @claude mentions in PRs/issues
- Add `make test` and `make check` targets for shellcheck validation
- Update `yolo-run.sh` to accept optional prompt argument for one-shot execution
- Update `entrypoint.sh` to detect prompt mode and execute accordingly
- Update one-shot mode to stream output to both terminal and timestamped log file
- Update README with installation steps, directory structure diagrams, and architecture explanation
- Update container execution with `docker run -dit` for full interactivity
- Update container to support `docker attach` for live interaction (detach with Ctrl+P Ctrl+Q)
- Fix lock file to prevent parallel YOLO execution in same directory
- Fix cleanup of lock file and container on script exit/interrupt
- Fix shellcheck warnings in trap and variable quoting
