# Proposal

## Why

Consistent personal reflection and daily activity tracking are difficult to maintain without automatic reminders. By prompting the user at 2:00 AM (or as soon as their Mac wakes up), this tool ensures a daily capture of accomplishments and activities with zero cognitive friction, storing entries in an open, lightweight text-based format.

## What Changes

- Add a Python CLI backend (`logger.py`) to append and query daily activity logs in a JSON Lines (`.txt`) database.
- Add a native Swift macOS floating desktop window application that presents a non-intrusive prompt: "What did you do today?" with a text input area, submit button, and keyboard shortcuts (`Cmd+Enter`).
- Swift application invokes the Python backend via subprocess execution (`Process`) without running background servers or daemon ports.
- Add a macOS `launchd` LaunchAgent configuration scheduled to trigger daily at 02:00 AM, automatically invoking the prompt on system wake if the machine was asleep.

## Capabilities

### New Capabilities
- `daily-logging`: Prompting daily at 2:00 AM (or system wake), capturing log text via a Swift floating window, executing Python CLI subprocesses, and persisting records to a JSON Lines text file.

### Modified Capabilities
<!-- None -->

## Impact

- Introduces new project files: Python CLI backend script, Swift macOS application sources, and a LaunchAgent `.plist` template.
- Storage is localized to a configured text file (e.g. `~/daily_logs.txt` or project root).
- System impact is minimal: no long-running server processes or open ports.
