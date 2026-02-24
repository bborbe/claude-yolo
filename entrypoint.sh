#!/bin/bash
set -euo pipefail

# Firewall
sudo /usr/local/bin/init-firewall.sh

# Run Claude
# exec bash
exec claude --dangerously-skip-permissions --model claude-sonnet-4-5
