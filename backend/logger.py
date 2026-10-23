#!/usr/bin/env python3
"""
backend/logger.py - Daily Logger CLI backend

Persists and queries daily activity logs in a JSON Lines text file.
Designed to be invoked via CLI subprocess by the Swift macOS application.
"""

import argparse
import json
import os
import sys
import uuid
from datetime import datetime, timedelta
from pathlib import Path


def get_default_log_file() -> Path:
    """Resolve the default log file path.
    Prioritizes DAILY_LOG_FILE env var, then repo root or current directory.
    """
    env_path = os.environ.get("DAILY_LOG_FILE")
    if env_path:
        return Path(env_path).expanduser().resolve()
    
    repo_file = Path(__file__).resolve().parent.parent / "daily_logs.txt"
    if repo_file.exists() or repo_file.parent.exists():
        return repo_file

    # Default to current directory if writable, else ~/daily_logs.txt
    local_path = Path("daily_logs.txt").resolve()
    return local_path


def get_logical_date(dt: datetime = None) -> str:
    """Calculate the logical cycle date.
    If the current time is between 00:00 and 04:59, attribute to yesterday.
    Otherwise attribute to today.
    """
    if dt is None:
        dt = datetime.now()
    if dt.hour < 5:
        logical_dt = dt - timedelta(days=1)
    else:
        logical_dt = dt
    return logical_dt.strftime("%Y-%m-%d")


def read_all_logs(file_path: Path):
    """Read all entries from the JSON Lines text file."""
    if not file_path.exists():
        return []
    
    entries = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                entries.append(data)
            except json.JSONDecodeError:
                # Skip or warn on malformed lines
                continue
    return entries


def cmd_log(args):
    """Append a log entry."""
    file_path = Path(args.file).expanduser().resolve() if args.file else get_default_log_file()
    now = datetime.now()
    logical_date = args.date if args.date else get_logical_date(now)
    
    entry_text = args.text
    if not entry_text:
        # Check stdin if not provided in arguments
        if not sys.stdin.isatty():
            entry_text = sys.stdin.read().strip()
            
    if not entry_text:
        print(json.dumps({"error": "Empty entry text"}), file=sys.stderr)
        return 1

    record = {
        "id": uuid.uuid4().hex[:8],
        "timestamp": now.isoformat(timespec="seconds"),
        "date": logical_date,
        "entry": entry_text.strip(),
    }

    # Ensure parent directory exists
    file_path.parent.mkdir(parents=True, exist_ok=True)

    with open(file_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")

    print(json.dumps({"status": "success", "record": record}))
    return 0


def cmd_has_logged(args):
    """Check if an entry has already been recorded for the logical date."""
    file_path = Path(args.file).expanduser().resolve() if args.file else get_default_log_file()
    target_date = args.date if args.date else get_logical_date()

    entries = read_all_logs(file_path)
    matching = [e for e in entries if e.get("date") == target_date]

    has_logged = len(matching) > 0
    response = {
        "has_logged": has_logged,
        "date": target_date,
        "count": len(matching)
    }
    print(json.dumps(response))
    return 0 if has_logged else 1


def cmd_list(args):
    """List recent entries."""
    file_path = Path(args.file).expanduser().resolve() if args.file else get_default_log_file()
    entries = read_all_logs(file_path)

    if args.reverse:
        entries = list(reversed(entries))

    if args.limit and args.limit > 0:
        entries = entries[:args.limit]

    print(json.dumps({"entries": entries, "count": len(entries)}))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Daily Logger Backend CLI")
    parser.add_argument("--file", help="Path to JSON Lines text database file")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommand: log
    p_log = subparsers.add_parser("log", help="Append a new log entry")
    p_log.add_argument("--text", "-t", help="Text entry content")
    p_log.add_argument("--date", "-d", help="Explicit logical date (YYYY-MM-DD)")
    p_log.set_defaults(func=cmd_log)

    # Subcommand: has-logged
    p_has = subparsers.add_parser("has-logged", help="Check if log exists for date")
    p_has.add_argument("--date", "-d", help="Explicit logical date (YYYY-MM-DD)")
    p_has.set_defaults(func=cmd_has_logged)

    # Subcommand: list
    p_list = subparsers.add_parser("list", help="List logged entries")
    p_list.add_argument("--limit", "-n", type=int, default=10, help="Max entries to return")
    p_list.add_argument("--reverse", "-r", action="store_true", help="Reverse chronological order")
    p_list.set_defaults(func=cmd_list)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
