---
status: completed
summary: Replaced files/stream-formatter.py with v2 implementation, added YOLO_OUTPUT=json mode to entrypoint.sh, deleted stream-formatter-v2.py prototype, updated CHANGELOG.md and CLAUDE.md
container: claude-yolo-008-upgrade-stream-formatter-and-add-json-output
dark-factory-version: v0.111.2
created: "2026-04-16T17:15:00Z"
queued: "2026-04-16T16:31:58Z"
started: "2026-04-16T16:32:02Z"
completed: "2026-04-16T16:33:37Z"
---

<summary>
- Stream formatter gains richer logging: session init stats, tool errors, bash failure tails, Edit diff previews, Agent prompts/replies, TodoWrite progress, and final result stats (duration, cost, tokens).
- Tool results are now correlated with their invocations so error output is attributed to the originating tool.
- A new `json` output mode emits raw stream-json directly to stdout without formatting, useful for external processors or debugging the underlying stream.
- The existing `print` mode (raw text) and default `stream` mode (formatted) keep working unchanged.
- The prototype formatter-v2 file is removed; its content replaces the production formatter.
- CHANGELOG records the user-visible feature additions.
- Architecture documentation mentions the three output modes.
</summary>

<objective>
Replace `files/stream-formatter.py` with the already-written, tested v2 implementation and add a third container output mode `json` (raw stream-json, no formatter) alongside the existing `print` and `stream` modes. End state: users can opt into machine-readable JSONL output, and the default formatted stream is substantially more informative.
</objective>

<context>
Read `CLAUDE.md` for project conventions — in particular the "No `docker` or `make build` in prompt verification" rule and the "Python 3 stdlib only" constraint.

Key files to read before making changes:
- `files/stream-formatter-v2.py` — the already-written, tested replacement. Its content must be copied verbatim into `files/stream-formatter.py`. Do NOT re-derive the logic.
- `files/stream-formatter.py` — the current minimal formatter that must be overwritten.
- `files/entrypoint.sh` — container entrypoint. Has a two-way `if [ "$OUTPUT" = "print" ]; then ... else ... fi` block around the `claude` exec; needs to become a three-way `if/elif/else`.
- `CHANGELOG.md` — check recent entries for version bump convention. Current top version is `v0.5.4`. A new `## Unreleased` section should be added above `## v0.5.4` (see how prompt 006/007 handled it).
- `CLAUDE.md` — Architecture section (around the bullet for `files/stream-formatter.py`) may need a wording tweak to acknowledge the three output modes.
</context>

<requirements>

### 1. Overwrite `files/stream-formatter.py` with the v2 content

Copy the entire content of `files/stream-formatter-v2.py` (verbatim, including the module docstring, constants, all functions, and the `if __name__ == "__main__":` guard) into `files/stream-formatter.py`, replacing its existing content completely.

Do NOT re-derive or paraphrase the logic — this file was tested against a real 414 KB session JSONL and must be copied as-is.

Preserve the shebang line `#!/usr/bin/env python3` at the top.

### 2. Delete `files/stream-formatter-v2.py`

Remove the file entirely. It was a prototype; after step 1 its content lives in `files/stream-formatter.py` and the prototype is obsolete.

### 3. Add a new `json` output mode in `files/entrypoint.sh`

Current structure (inside the `if [ -n "${PROMPT_FILE:-}" ]; then` block, after `echo "Starting headless session..."`):

```sh
if [ "$OUTPUT" = "print" ]; then
    exec setpriv --reuid=node --regid=node --init-groups -- \
        claude --print -p --dangerously-skip-permissions \
        --model "$MODEL" --verbose < "$PROMPT_FILE"
else
    # exec + pipe requires sh -c; pass MODEL and PROMPT_FILE as positional args to avoid quoting issues
    # shellcheck disable=SC2016
    exec setpriv --reuid=node --regid=node --init-groups -- \
        sh -c 'claude -p --dangerously-skip-permissions --model "$1" \
               --output-format stream-json --verbose < "$2" \
               | python3 /usr/local/bin/stream-formatter.py' \
        _ "$MODEL" "$PROMPT_FILE"
fi
```

Replace with a three-way branch that inserts a new `elif [ "$OUTPUT" = "json" ]` branch between the `print` and default branches:

```sh
if [ "$OUTPUT" = "print" ]; then
    exec setpriv --reuid=node --regid=node --init-groups -- \
        claude --print -p --dangerously-skip-permissions \
        --model "$MODEL" --verbose < "$PROMPT_FILE"
elif [ "$OUTPUT" = "json" ]; then
    exec setpriv --reuid=node --regid=node --init-groups -- \
        claude -p --dangerously-skip-permissions \
        --model "$MODEL" --output-format stream-json --verbose < "$PROMPT_FILE"
else
    # exec + pipe requires sh -c; pass MODEL and PROMPT_FILE as positional args to avoid quoting issues
    # shellcheck disable=SC2016
    exec setpriv --reuid=node --regid=node --init-groups -- \
        sh -c 'claude -p --dangerously-skip-permissions --model "$1" \
               --output-format stream-json --verbose < "$2" \
               | python3 /usr/local/bin/stream-formatter.py' \
        _ "$MODEL" "$PROMPT_FILE"
fi
```

Requirements for this branch:
- MUST use the `exec setpriv --reuid=node --regid=node --init-groups --` pattern, same as the other two branches.
- MUST NOT pipe through `python3 /usr/local/bin/stream-formatter.py`.
- MUST pass `--output-format stream-json --verbose` so the raw JSONL is emitted.
- MUST use direct `< "$PROMPT_FILE"` redirection (no `sh -c` wrapper needed — there is no pipe).
- Do NOT modify the existing `print` branch or the default (formatted stream) branch beyond fitting into the new `if/elif/else` structure.

Also update the inline comment above the `OUTPUT=` variable (around `# Output format: "print" for raw text, default uses stream-json + formatter`) to reflect three modes, e.g.:
```sh
# Output format:
#   "print"  = raw text via `claude --print`
#   "json"   = raw stream-json JSONL (no formatter)
#   default  = stream-json piped through the formatter
```

### 4. Update `CHANGELOG.md`

Add a new `## Unreleased` section above the current top entry (`## v0.5.4`) with two bullet points describing the user-visible changes:

```
## Unreleased

- feat: Add `YOLO_OUTPUT=json` mode that emits raw stream-json to stdout without the formatter (useful for external processing)
- feat: Richer stream-formatter output — session init stats, tool error flags, bash failure tails, Edit diff previews, Agent prompt/reply, TodoWrite progress, and final duration/cost/token stats
```

Do NOT bump the version in the CHANGELOG — dark-factory's release automation handles version tagging. Just add the `## Unreleased` section.

### 5. Update `CLAUDE.md` Architecture section

Find the line describing `files/stream-formatter.py` (currently: `files/stream-formatter.py — Reads Claude Code stream-json from stdin, formats into readable progress lines`) and replace it with:

```
- `files/stream-formatter.py` — Reads Claude Code stream-json from stdin, formats into readable progress lines (used by default; bypassed when YOLO_OUTPUT=print or YOLO_OUTPUT=json)
```

Do NOT rewrite any other part of `CLAUDE.md`.

### 6. Verify the finished state

After making all the above changes, run the two verification commands listed under `<verification>` below and confirm both exit 0.

</requirements>

<constraints>
- Do NOT commit — dark-factory handles git.
- Do NOT bump the version number in CHANGELOG.md — release automation handles that.
- stream-formatter.py MUST use stdlib only (no pip dependencies). The v2 file already complies.
- Do NOT modify the existing `print` branch in entrypoint.sh; preserve it byte-for-byte.
- Do NOT modify the default stream+formatter branch logic except for the structural `else` placement inside the new `if/elif/else`.
- The new `json` branch MUST NOT pipe through stream-formatter.py.
- All three branches MUST keep the `exec setpriv --reuid=node --regid=node --init-groups --` pattern.
- No `docker`, `make build`, or anything requiring a Docker socket — dark-factory runs inside a container without Docker.
- `entrypoint.sh` must remain shellcheck-clean (shellcheck runs via `make precommit`).
- Do NOT modify `Dockerfile`, `scripts/yolo-run.sh`, `scripts/yolo-prompt.sh`, `files/init-firewall.sh`, `files/tinyproxy.conf`, or `files/tinyproxy-allowlist` — this change is limited to the formatter, entrypoint, CHANGELOG, and (optionally) CLAUDE.md.
- Overwriting `files/stream-formatter.py`: copy v2 content verbatim — do not re-derive, re-order, rename, or "improve" any function.
</constraints>

<verification>
Both commands must exit 0:

```
python3 -m py_compile files/stream-formatter.py
make precommit
```

After those pass, also verify by inspection:

```
test ! -e files/stream-formatter-v2.py    # v2 file deleted
grep -c 'elif \[ "\$OUTPUT" = "json" \]' files/entrypoint.sh   # returns 1
grep -c '## Unreleased' CHANGELOG.md       # returns 1
grep -c '| python3 /usr/local/bin/stream-formatter.py' files/entrypoint.sh   # returns 1 (only the default branch pipes through it)
grep -q 'tool_use_id -> (name, input) map' files/stream-formatter.py   # confirms v2 content copied (string appears in v2 docstring)
```
</verification>
