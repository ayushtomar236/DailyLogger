# Design

## Context

The daily logger is composed of a native macOS Swift UI and a Python CLI backend. To keep the footprint minimal, the system runs with zero persistent daemon services or background open ports. Scheduling is delegated to macOS native `launchd`, which executes the Swift application at 02:00 AM (or on wake).

## Goals / Non-Goals

**Goals:**
- Provide a clean, native floating window prompt for entering daily activities.
- Support instant keyboard shortcuts (`Cmd+Enter` to submit, `Esc` or button to dismiss).
- Execute Python CLI commands via `Foundation.Process` for log persistence and status checks.
- Append logs to a plain text file using the JSON Lines format.
- Ensure the prompt fires reliably at 02:00 AM or upon laptop wake.

**Non-Goals:**
- No local HTTP web server, daemon listeners, or network socket communication.
- No remote cloud database or sync services.
- No complex rich-text or markdown preview rendering.

## Decisions

### 1. IPC Mechanism: Subprocess CLI Execution
- **Decision**: Swift invokes the Python script directly using `Foundation.Process` with arguments (e.g., `python3 backend/logger.py log --text "..."`).
- **Rationale**: Eliminates background process management, memory leaks, and port conflict risks. Python only runs during reads/writes.
- **Alternatives Considered**: Local HTTP server (FastAPI) — rejected due to daemon overhead and open localhost ports.

### 2. Window Presentation: Centered Floating NSWindow
- **Decision**: Use a dedicated floating desktop window (`NSWindow.Level.floating`) centered on screen, displaying a focused SwiftUI multi-line text input.
- **Rationale**: Guarantees the prompt is immediately visible when triggered, without requiring user hunting in the menu bar.
- **Alternatives Considered**: Menu bar popover — rejected per user requirement for a floating desktop window.

### 3. Database Format: JSON Lines in a Text File
- **Decision**: Store logs in `daily_logs.txt` (or configured path) where each line is an independent JSON object:
  ```json
  {"id": "a1b2c3d4", "timestamp": "2026-10-24T02:00:15", "date": "2026-10-23", "entry": "Log content"}
  ```
- **Rationale**: Easy to append to without parsing or rewriting the entire file; human-readable and straightforward to query.
- **Alternatives Considered**: Raw unstructured text, SQLite, or single large JSON array.

### 4. Scheduling: macOS launchd LaunchAgent
- **Decision**: Provide a `com.user.dailylogger.plist` LaunchAgent using `StartCalendarInterval` for 02:00.
- **Rationale**: macOS native behavior automatically runs jobs on system wake if the computer was asleep when scheduled.

## Project Structure

```
logger/
├── backend/
│   ├── logger.py            # Python CLI script (log, has-logged, list)
│   └── test_logger.py       # Unit tests for backend
├── ui/
│   ├── Package.swift        # Swift Package / App configuration
│   └── Sources/
│       └── DailyLogger/
│           ├── main.swift   # App entry point & NSApplication setup
│           ├── Views/       # SwiftUI floating prompt window
│           └── Services/    # Process executor for Python backend
├── launchd/
│   └── com.user.dailylogger.plist # macOS LaunchAgent template
└── daily_logs.txt           # Text database file
```

## Risks / Trade-offs

- **[Python Interpreter Path]** → Swift will look for `python3` in `/usr/bin/python3`, `/usr/local/bin/python3`, `/opt/homebrew/bin/python3`, or an environment variable `LOGGER_PYTHON_PATH`.
- **[Multiple Launches on Repeated Wakes]** → The Swift app queries `logger.py has-logged` upon launch; if an entry for the date cycle already exists, it terminates quietly without flashing a window.
