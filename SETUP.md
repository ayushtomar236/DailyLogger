# Daily Logger Setup & Run Guide

A native macOS application that prompts you with a focused, floating desktop window at **02:00 AM** (or immediately upon computer wake) asking *"What did you do today?"*, and appends entries to a plain-text JSON Lines file.

---

## Architecture Overview

- **Native macOS UI (`ui/`)**: Built in Swift and SwiftUI. Provides a lightweight, floating desktop prompt (`NSWindow.Level.floating`) with keyboard shortcuts (`Cmd+Enter` to submit, `Esc` or button to dismiss).
- **Backend & Storage (`backend/logger.py`)**: Zero-daemon Python CLI. Appends and queries single-line JSON records in `daily_logs.txt`.
- **macOS Automation (`launchd/`)**: Scheduled via a user LaunchAgent (`com.user.dailylogger.plist`) with `StartCalendarInterval` at 02:00 AM. Native macOS `launchd` triggers the job upon wake if the computer was asleep at 02:00 AM.

---

## Prerequisites

Before setting up the project, ensure you have:

1. **macOS**: Tested on macOS 13+ (Ventura, Sonoma, Sequoia) on both Apple Silicon and Intel.
2. **Swift & Apple Command Line Tools**:
   ```bash
   xcode-select --install   # If not already installed
   swift --version          # Swift 5.9+ or Swift 6.x
   ```
3. **Python 3**:
   ```bash
   python3 --version        # Python 3.8+
   ```

---

## 1. Quick Automated Setup (Recommended)

Run the included automated setup script from the root of the repository:

```bash
./setup.sh
```

### What `setup.sh` does:
1. Validates `swift` and `python3` installations.
2. Compiles the Swift UI application in release mode (`swift build -c release`).
3. Installs the binary to `bin/DailyLoggerUI`.
4. Copies and configures the `com.user.dailylogger.plist` LaunchAgent into `~/Library/LaunchAgents/`.
5. Runs an integration test against the Python backend to confirm verification logic.

---

## 2. Activating the Automatic 02:00 AM / Wake Trigger

After running `setup.sh`, register the LaunchAgent with macOS:

```bash
launchctl load ~/Library/LaunchAgents/com.user.dailylogger.plist
```

To verify that the agent is loaded:
```bash
launchctl list | grep com.user.dailylogger
```

> **How it works:**
> - If your Mac is awake at **02:00 AM**, the prompt appears centered on your screen.
> - If your Mac is asleep at 02:00 AM, macOS `launchd` fires the prompt **immediately upon waking and unlocking**.
> - If you already logged an entry for the cycle, the prompt suppresses itself silently.

---

## 3. Manual Build & Run Instructions

If you prefer building and running manually without `setup.sh`:

### Build the Swift Binary
```bash
# Compile release binary
swift build -c release --package-path ui

# Copy binary to bin/
mkdir -p bin
cp ui/.build/release/DailyLoggerUI bin/DailyLoggerUI
chmod +x bin/DailyLoggerUI
```

### Run the UI Directly

| Goal | Command |
| :--- | :--- |
| **Test prompt immediately** (forces window even if already logged) | `./bin/DailyLoggerUI --force` |
| **Normal trigger** (checks if already logged; shows prompt only if pending) | `./bin/DailyLoggerUI` |
| **Check today's status** (exits `0` if logged, `1` if not) | `./bin/DailyLoggerUI --check` |

### Running in Development Mode
You can also run directly with Swift Package Manager:
```bash
swift run --package-path ui DailyLoggerUI --force
```

---

## 4. UI Shortcuts & Behavior

When the floating prompt window appears:

| Key / Action | Result |
| :--- | :--- |
| **`Cmd + Enter`** | Saves the log entry and dismisses the window. |
| **"Save Log" Button** | Saves the log entry and dismisses the window. |
| **"Dismiss" / "Cancel"** | Closes the window without saving. |
| **Window Drag** | You can drag the window anywhere by clicking and dragging its background. |

---

## 5. Backend CLI & Data Management

You can inspect, query, or manually log entries using `backend/logger.py`:

### Check if Logged for Today
```bash
python3 backend/logger.py has-logged
```
Output:
```json
{"has_logged": false, "date": "2026-10-23", "count": 0}
```

### Manually Add a Log Entry
```bash
python3 backend/logger.py log --text "Completed project documentation and tested release binary."
```

### List Recent Entries
```bash
# List last 10 entries in reverse chronological order
python3 backend/logger.py list --limit 10 --reverse
```

### Data Storage Format (`daily_logs.txt`)
Entries are saved in JSON Lines format (`.txt`), one record per line:
```json
{"id": "c8a41df2", "timestamp": "2026-10-24T00:18:13", "date": "2026-10-23", "entry": "Worked on Daily Logger UI and launchd setup."}
```

### Logical Day Cycle (Night Owl Window)
Logs recorded between **00:00 AM and 04:59 AM** are attributed to the **previous calendar day's cycle**.
- Example: A prompt triggered at 02:00 AM on Oct 24 records the entry with `"date": "2026-10-23"`.
- This ensures reflection at 2:00 AM logs what you accomplished during the day you just finished.

---

## 6. Managing & Unloading the LaunchAgent

To disable or update the scheduled trigger:

```bash
# Unload (disable) the agent
launchctl unload ~/Library/LaunchAgents/com.user.dailylogger.plist

# Reload after making changes to the plist
launchctl unload ~/Library/LaunchAgents/com.user.dailylogger.plist
launchctl load ~/Library/LaunchAgents/com.user.dailylogger.plist
```

To view `launchd` execution logs:
```bash
tail -f /tmp/DailyLogger.stdout.log
tail -f /tmp/DailyLogger.stderr.log
```

---

## 7. Environment Variables & Customization

The application supports the following optional environment variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `DAILY_LOG_FILE` | Custom path to the JSON Lines text file. | `<repo-root>/daily_logs.txt` |
| `LOGGER_PYTHON_PATH` | Path to a specific Python 3 interpreter. | Auto-detected (`python3` in PATH / Homebrew) |
| `LOGGER_BACKEND_SCRIPT`| Path to `backend/logger.py`. | Auto-detected relative to binary / CWD |

---

## 8. Running Automated Tests

To run the backend test suite:

```bash
python3 -m unittest backend/test_logger.py
```
All unit tests should pass with `OK`.
