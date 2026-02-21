#!/bin/bash
set -euo pipefail

# Firewall
sudo /usr/local/bin/init-firewall.sh

export GOPATH=/home/node/go

# Copy auth token into .claude dir (claude looks for it there too)
[ -f ~/.claude.json ] && cp ~/.claude.json ~/.claude/

exec claude --dangerously-skip-permissions --model claude-sonnet-4-6 
