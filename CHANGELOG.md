# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.0.8

### Changed

- Replaced IP-based firewall (ipset/dig/aggregate) with tinyproxy domain-based filtering
- Simplified init-firewall.sh: no more DNS resolution at startup
- Removed `ipset`, `dnsutils`, `aggregate` from container image

### Fixed

- CDN-backed domains (api.osv.dev, storage.googleapis.com) no longer break due to IP rotation after container init

### Added

- Domain allowlist at `/etc/tinyproxy/allowlist` for easy domain management
- HTTP_PROXY/HTTPS_PROXY env vars set automatically in entrypoint

## v0.0.7

### Added
- Support `YOLO_PROMPT_FILE` env var to read prompt from mounted file (avoids shell escaping issues with `-e` flag)

## v0.0.6

### Fixed
- Bare key access in stream-formatter.py replaced with `.get()` to prevent crash on malformed JSON
- Replace all `git -C` with `cd && git` in yolo-run.sh
- README Configuration section now matches actual Makefile variables
- Added missing yolo-prompt.sh usage documentation to README
- Added stream-formatter.py to project structure in README

### Changed
- Wrap stream-formatter.py in `main()` with `__name__` guard for testability

## v0.0.5

### Fixed
- Bare key access in stream-formatter.py replaced with `.get()` to prevent crash on malformed JSON
- Replace all `git -C` with `cd && git` in yolo-run.sh

### Changed
- Wrap stream-formatter.py in `main()` with `__name__` guard for testability

## v0.0.4

### Fixed
- Add `ghcr.io` and `pkg-containers.githubusercontent.com` to firewall allowlist so trivy can download its vulnerability database during `make precommit`

## v0.0.3

### Fixed
- Lock file not cleaned up on exit due to trap aborting on dead container
- Trap quoting so `$LOCK_FILE` expands correctly
- Replace `git -C` with `cd && git` in yolo-prompt.sh

## v0.0.2

### Changed
- Auto-detect version from git tags for docker image tagging
- `make build` now tags both versioned and `:latest` images
- `make upload` pushes both versioned and `:latest` tags

## v0.0.1

### Added
- One-shot mode: pass prompt as argument to `yolo-run.sh` for automated execution
- `YOLO_PROMPT` environment variable support in entrypoint for prompt passthrough
- Comprehensive README examples for both interactive and one-shot modes
- Streaming logs to `.logs/yolo-YYYY-MM-DD-HH-MM-SS.log` with real-time output
- Auto-gitignore `.logs/` directory in target workspace
- Distribution setup with `~/.claude-yolo` configuration directory
- Sample CLAUDE.md workflow configuration in `examples/`
- Slash commands (`create-prompt.md`, `run-prompt.md`) in `commands/`
- `yolo-prompt.sh` helper script for executing prompts by number
- Installation and setup documentation in README
- Attribution to taches-cc-resources in slash command files
- CI workflow with shellcheck validation (`make test`)
- Claude Code workflow for @claude mentions in PRs/issues
- `make test` and `make check` targets for shellcheck validation

### Changed
- `yolo-run.sh` now accepts optional prompt argument for one-shot execution
- `entrypoint.sh` detects prompt mode and executes accordingly
- One-shot mode streams output to both terminal and timestamped log file
- README updated with installation steps, directory structure diagrams, and architecture explanation
- Simplified container execution with `docker run -dit` for full interactivity
- Container now supports `docker attach` for live interaction (detach with Ctrl+P Ctrl+Q)
- Display container ID and attach instructions on startup

### Fixed
- Lock file prevents parallel YOLO execution in same directory
- Proper cleanup of lock file and container on script exit/interrupt
- Shellcheck warnings in trap and variable quoting

### Use Cases
- Automated task execution from spec files
- CI/CD integration
- Dark Factory pattern (spec → implementation → exit)
- Batch processing of coding tasks
- Prompt-based workflow with `/create-prompt` and `/run-prompt` commands
