# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- One-shot mode: pass prompt as argument to `run-yolo.sh` for automated execution
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
- `run-yolo.sh` now accepts optional prompt argument for one-shot execution
- `entrypoint.sh` detects prompt mode and executes accordingly
- One-shot mode streams output to both terminal and timestamped log file
- README updated with installation steps, directory structure diagrams, and architecture explanation

### Use Cases
- Automated task execution from spec files
- CI/CD integration
- Dark Factory pattern (spec → implementation → exit)
- Batch processing of coding tasks
- Prompt-based workflow with `/create-prompt` and `/run-prompt` commands
