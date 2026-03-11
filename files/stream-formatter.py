#!/usr/bin/env python3
"""Format Claude Code stream-json output into readable progress."""
import json
import sys
from datetime import datetime


def ts() -> str:
    return datetime.now().strftime("[%H:%M:%S]")


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            print(f"{ts()} {line}", flush=True)
            continue

        t = d.get("type", "")

        if t == "assistant":
            msg = d.get("message", {})
            for c in msg.get("content", []):
                ct = c.get("type", "")
                if ct == "text":
                    print(f"{ts()} {c.get('text', '')}", flush=True)
                elif ct == "tool_use":
                    name = c.get("name", "")
                    inp = c.get("input", {})
                    if name == "Bash":
                        print(f"{ts()} $ {inp.get('command', '')}", flush=True)
                    elif name == "Read":
                        print(f"{ts()} [read] {inp.get('file_path', '')}", flush=True)
                    elif name == "Write":
                        print(f"{ts()} [write] {inp.get('file_path', '')}", flush=True)
                    elif name == "Edit":
                        print(f"{ts()} [edit] {inp.get('file_path', '')}", flush=True)
                    elif name == "Grep":
                        print(f"{ts()} [grep] {inp.get('pattern', '')}", flush=True)
                    elif name == "Glob":
                        print(f"{ts()} [glob] {inp.get('pattern', '')}", flush=True)
                    else:
                        print(f"{ts()} [{name}]", flush=True)
        elif t == "tool_result":
            pass  # skip raw tool output
        elif t == "result":
            result = d.get("result", "")
            if result:
                print(f"\n{ts()} --- DONE ---\n{result}", flush=True)


if __name__ == "__main__":
    main()
