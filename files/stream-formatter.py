#!/usr/bin/env python3
"""Format Claude Code stream-json output into readable progress.

v2 improvements over v1:
- Logs system init (session id, model, cwd, tool count)
- Logs bash exit code; shows stderr + last 20 lines stdout on failure
- Highlights tool errors (is_error=true)
- Shows Edit old_string -> new_string preview (truncated)
- Shows Agent description + prompt preview
- Shows TodoWrite status transitions
- Shows WebFetch/WebSearch URL/query
- Logs final result stats (duration, cost, tokens)
- Maintains tool_use_id -> (name, input) map for correlated result logging
"""
import json
import sys
from datetime import datetime
from typing import Any

MAX_LINE = 200           # max chars per preview line
MAX_TAIL_LINES = 20      # bash stdout tail on error
MAX_PROMPT_CHARS = 160   # Agent prompt preview


def ts() -> str:
    return datetime.now().strftime("[%H:%M:%S]")


def shorten(s: str, n: int = MAX_LINE) -> str:
    s = s.replace("\n", "\\n")
    return s if len(s) <= n else s[: n - 1] + "…"


def emit(msg: str) -> None:
    print(f"{ts()} {msg}", flush=True)


def emit_err(msg: str) -> None:
    print(f"{ts()} ⚠ {msg}", flush=True)


def handle_system(d: dict[str, Any]) -> None:
    if d.get("subtype") != "init":
        return
    sid = d.get("session_id", "?")[:8]
    model = d.get("model", "?")
    cwd = d.get("cwd", "?")
    tools = len(d.get("tools", []))
    emit(f"[init] session={sid} model={model} cwd={cwd} tools={tools}")


def handle_assistant(d: dict[str, Any], tool_log: dict[str, dict[str, Any]]) -> None:
    msg = d.get("message", {})
    for c in msg.get("content", []):
        ct = c.get("type", "")
        if ct == "text":
            text = c.get("text", "").strip()
            if text:
                emit(text)
        elif ct == "thinking":
            # show first line only so it's not overwhelming
            think = c.get("thinking", "").strip().splitlines()
            if think:
                emit(f"💭 {shorten(think[0])}")
        elif ct == "tool_use":
            name = c.get("name", "")
            inp = c.get("input", {}) or {}
            tid = c.get("id", "")
            tool_log[tid] = {"name": name, "input": inp}
            emit(format_tool_use(name, inp))


def format_tool_use(name: str, inp: dict[str, Any]) -> str:
    if name == "Bash":
        return f"$ {shorten(inp.get('command', ''))}"
    if name == "Read":
        fp = inp.get("file_path", "")
        rng = ""
        if inp.get("offset") or inp.get("limit"):
            rng = f" (offset={inp.get('offset', 0)}, limit={inp.get('limit', '')})"
        return f"[read] {fp}{rng}"
    if name == "Write":
        sz = len(inp.get("content", ""))
        return f"[write] {inp.get('file_path', '')} ({sz} chars)"
    if name == "Edit":
        fp = inp.get("file_path", "")
        old = shorten(inp.get("old_string", ""), 60)
        new = shorten(inp.get("new_string", ""), 60)
        return f"[edit] {fp}\n    - {old}\n    + {new}"
    if name == "Grep":
        pat = inp.get("pattern", "")
        path = inp.get("path", "")
        glob = inp.get("glob", "")
        extras = " ".join(x for x in (f"path={path}" if path else "", f"glob={glob}" if glob else "") if x)
        return f"[grep] {pat}" + (f"  ({extras})" if extras else "")
    if name == "Glob":
        return f"[glob] {inp.get('pattern', '')}"
    if name in ("Task", "Agent"):
        desc = inp.get("description", "")
        sub = inp.get("subagent_type", "general")
        prompt = shorten(inp.get("prompt", ""), MAX_PROMPT_CHARS)
        return f"[agent:{sub}] {desc}\n    prompt: {prompt}"
    if name == "WebFetch":
        return f"[webfetch] {inp.get('url', '')}"
    if name == "WebSearch":
        return f"[websearch] {inp.get('query', '')}"
    if name == "ToolSearch":
        return f"[toolsearch] {shorten(inp.get('query', ''), 100)}"
    if name == "AskUserQuestion":
        q = inp.get("question", "") or (inp.get("questions", [{}])[0].get("question", "") if inp.get("questions") else "")
        return f"[ask] {shorten(q, 120)}"
    if name == "Skill":
        return f"[skill] /{inp.get('skill', '')} {inp.get('args', '')}".rstrip()
    if name.startswith("mcp__"):
        parts = name.split("__", 2)
        server = parts[1] if len(parts) > 1 else "?"
        method = parts[2] if len(parts) > 2 else "?"
        return f"[mcp:{server}] {method}"
    if name == "TodoWrite":
        todos = inp.get("todos", [])
        active = next((t for t in todos if t.get("status") == "in_progress"), None)
        done = sum(1 for t in todos if t.get("status") == "completed")
        total = len(todos)
        if active:
            return f"[todo] {done}/{total} active: {shorten(active.get('content', ''), 80)}"
        return f"[todo] {done}/{total} done"
    if name == "NotebookEdit":
        return f"[notebook] {inp.get('notebook_path', '')}"
    return f"[{name}]"


def handle_user(d: dict[str, Any], tool_log: dict[str, dict[str, Any]]) -> None:
    msg = d.get("message", {})
    content = msg.get("content", [])
    if not isinstance(content, list):
        return
    for c in content:
        if not isinstance(c, dict) or c.get("type") != "tool_result":
            continue
        tid = c.get("tool_use_id", "")
        is_error = bool(c.get("is_error"))
        tool_entry = tool_log.get(tid, {})
        name = tool_entry.get("name", "?")
        result = c.get("content", "")
        # content can be a list of content blocks or a string
        text = extract_text(result)
        format_tool_result(name, tool_entry.get("input", {}) or {}, text, is_error)


def extract_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text":
                parts.append(c.get("text", ""))
            elif isinstance(c, str):
                parts.append(c)
        return "\n".join(parts)
    return ""


def format_tool_result(name: str, inp: dict[str, Any], text: str, is_error: bool) -> None:
    if is_error:
        emit_err(f"[{name}] error: {shorten(text, 400)}")
        return

    if name == "Bash":
        # Parse Claude Code bash result envelope if present (exit code shows in stderr tag)
        lower = text.lower()
        looks_failed = any(s in lower for s in ("error", "exit code", "failed", "fatal"))
        if looks_failed:
            tail = "\n".join(text.splitlines()[-MAX_TAIL_LINES:])
            emit_err(f"[bash output]\n{tail}")
        # otherwise stay quiet (the $ command line is enough)
        return

    if name == "Read":
        lines = text.count("\n")
        emit(f"  → {lines} lines read")
        return

    if name in ("Write", "Edit"):
        # short confirmation if there's any message
        first = text.strip().splitlines()[:1]
        if first:
            emit(f"  → {shorten(first[0], 120)}")
        return

    if name == "Grep":
        nl = text.count("\n")
        # show file match count or first match summary
        emit(f"  → {nl} match lines")
        return

    if name == "Glob":
        nl = text.count("\n")
        emit(f"  → {nl} files")
        return

    if name in ("Task", "Agent"):
        # agents produce long text; log first line of final answer
        first = (text.strip().splitlines() or [""])[0]
        emit(f"  ← agent reply: {shorten(first, 200)}")
        return

    # default: stay silent unless error


def handle_result(d: dict[str, Any]) -> None:
    duration_ms = d.get("duration_ms")
    cost = d.get("total_cost_usd")
    usage = d.get("usage", {}) or {}
    in_tok = usage.get("input_tokens", 0)
    out_tok = usage.get("output_tokens", 0)
    cache_read = usage.get("cache_read_input_tokens", 0)
    subtype = d.get("subtype", "")
    is_error = d.get("is_error", False)

    stats_parts = []
    if duration_ms is not None:
        stats_parts.append(f"{duration_ms / 1000:.1f}s")
    if cost is not None:
        stats_parts.append(f"${cost:.4f}")
    if in_tok or out_tok:
        stats_parts.append(f"in={in_tok} out={out_tok} cache_r={cache_read}")
    stats = " | ".join(stats_parts)

    marker = "ERROR" if is_error else "DONE"
    emit(f"--- {marker} ({subtype}) {stats} ---")

    result = d.get("result", "")
    if result:
        print(result, flush=True)


def main() -> None:
    tool_log: dict[str, dict[str, Any]] = {}
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            emit(line)
            continue

        t = d.get("type", "")
        if t == "system":
            handle_system(d)
        elif t == "assistant":
            handle_assistant(d, tool_log)
        elif t == "user":
            handle_user(d, tool_log)
        elif t == "result":
            handle_result(d)


if __name__ == "__main__":
    main()
