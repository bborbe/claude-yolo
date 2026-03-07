<objective>
Pin the bborbe/updater installation in the Dockerfile to a fixed version tag (v0.15.1) instead of the default branch.
</objective>

<context>
Read CLAUDE.md for project conventions.
Read Dockerfile before changing it.

Currently line 95 installs updater without a version:
  RUN /home/node/.local/bin/uv tool install git+https://github.com/bborbe/updater

This makes it unclear which updater version is included in the image and makes builds non-reproducible.
</context>

<requirements>
1. Change the updater install command to pin to tag v0.15.1:
   RUN /home/node/.local/bin/uv tool install git+https://github.com/bborbe/updater@v0.15.1
</requirements>

<constraints>
- Only change the updater install line, nothing else
</constraints>

<verification>
Run `make build` to verify the Docker image builds successfully.
Then verify the version:
```bash
docker run --rm docker.io/bborbe/claude-yolo:latest updater --version
```
</verification>
