# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- One-shot mode: pass prompt as argument to `run-yolo.sh` for automated execution
- `YOLO_PROMPT` environment variable support in entrypoint for prompt passthrough
- Comprehensive README examples for both interactive and one-shot modes

### Changed
- `run-yolo.sh` now accepts optional prompt argument for one-shot execution
- `entrypoint.sh` detects prompt mode and executes accordingly

### Use Cases
- Automated task execution from spec files
- CI/CD integration
- Dark Factory pattern (spec → implementation → exit)
- Batch processing of coding tasks
