---
status: completed
summary: Added [HH:MM:SS] timestamp prefix to every print() call in files/stream-formatter.py via a ts() helper function.
container: claude-yolo-005-add-timestamps-to-stream-formatter
dark-factory-version: v0.44.0
created: "2026-03-11T20:41:18Z"
queued: "2026-03-11T20:41:18Z"
started: "2026-03-11T21:02:06Z"
completed: "2026-03-11T21:02:49Z"
---

<summary>
- Log lines get timestamp prefixes for timing analysis
- Format: [HH:MM:SS] before each output line
- Helps identify slow steps in prompt execution
- No changes to the JSON parsing or filtering logic
- Both tool actions and text output get timestamps
</summary>

<objective>
Add timestamps to the stream-formatter.py output so dark-factory logs show when each step happened. Currently logs have no timing information, making it impossible to analyze which steps take the longest.
</objective>

<context>
Read `files/stream-formatter.py` — this script reads Claude Code's stream-json output from stdin and formats it into readable progress lines. Its output goes to both terminal and the dark-factory log file (e.g., `prompts/log/172-fix-stop-on-failure.log`).
</context>

<requirements>
1. In `files/stream-formatter.py`, add a helper function that returns the current time formatted as `[HH:MM:SS]`:
   ```python
   from datetime import datetime

   def ts():
       return datetime.now().strftime("[%H:%M:%S]")
   ```
2. Prefix every `print()` call in the script with `{ts()} ` so output looks like:
   ```
   [21:15:03] Starting headless session...
   [21:15:05] [read] /workspace/pkg/processor/processor.go
   [21:22:47] $ make precommit
   [21:23:52] --- DONE ---
   ```
3. The "Starting headless session..." line comes from `entrypoint.sh`, not the formatter — leave that as-is (it won't get a timestamp from the formatter, which is fine)
4. Do not change the JSON parsing logic or which events are shown/hidden
</requirements>

<constraints>
- Do NOT commit — dark-factory handles git
- Only modify `files/stream-formatter.py`
- Keep the script simple — no external dependencies beyond stdlib
- Existing output format stays the same, just with a timestamp prefix
</constraints>

<verification>
Run `python3 -c "import files.stream_formatter"` or `python3 -m py_compile files/stream-formatter.py` — must not error.
</verification>
