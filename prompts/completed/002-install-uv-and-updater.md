---
status: completed
summary: Added uv and updater tool installations to Dockerfile
container: claude-yolo-002-install-uv-and-updater
dark-factory-version: dev
created: "2026-03-05T21:06:31Z"
queued: "2026-03-05T21:06:31Z"
started: "2026-03-05T21:06:31Z"
completed: "2026-03-05T21:07:20Z"
---

<objective>
Install uv (Python package manager) and the bborbe/updater tool in the Docker image so claude-yolo containers have `updater` available at runtime.
</objective>

<context>
Read CLAUDE.md for project conventions.
Read Dockerfile before changing it.

This is a Docker-based dev container (node:22 base). Tools are installed at build time in the Dockerfile.
The container has a firewall at runtime (tinyproxy) but Docker build has unrestricted network access.

uv is a fast Python package/tool manager. `uv tool install` installs CLI tools into isolated environments.

The updater tool is at: https://github.com/bborbe/updater
Install command: `uv tool install git+https://github.com/bborbe/updater`
</context>

<requirements>
1. Add uv installation to the Dockerfile (use the official install script: `curl -LsSf https://astral.sh/uv/install.sh | sh`)
2. Ensure uv binary is on PATH (installed to `$HOME/.local/bin` by default)
3. After uv is installed, run `uv tool install git+https://github.com/bborbe/updater` to install the updater tool
4. Ensure updater binary is on PATH (uv tools go to `$HOME/.local/bin`)
5. Both uv and updater installations must happen as the `node` user (after the `USER node` line)
</requirements>

<constraints>
- Do NOT modify any existing tool installations
- Do NOT change the firewall/tinyproxy configuration
- Keep the installation order logical (uv before updater, both after USER node)
</constraints>

<verification>
Run `make build` to verify the Docker image builds successfully.
Then verify the tools are available:
```bash
docker run --rm docker.io/bborbe/claude-yolo:latest uv --version
docker run --rm docker.io/bborbe/claude-yolo:latest updater --help
```
</verification>
