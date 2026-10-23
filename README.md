# 📝 Daily Logger

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue?logo=python)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A minimalist, distraction-free daily reflection tool for macOS. Every night at **02:00 AM** (or as soon as your Mac wakes up from sleep), a floating prompt appears asking:

> *"What did you do today?"*

Type your summary, hit `Cmd + Enter`, and get right back to what you were doing. Entries are saved instantly into a clean, human-readable **JSON Lines** text file.

---

## ✨ Features

- 🪟 **Floating Desktop Window**: Native Swift/SwiftUI interface positioned centered on your screen. Never gets lost behind other windows (`NSWindow.Level.floating`).
- ⚡ **Instant Keyboard Flow**: Press `Cmd + Enter` to submit and dismiss in seconds. Press `Esc` or click `Dismiss` if you're in the middle of something.
- ⏰ **Reliable Wake-up Triggering**: Powered by macOS native `launchd`. If your machine was asleep at 2:00 AM, the prompt greets you the moment you wake and unlock your computer.
- 🪶 **Zero-Daemon / Zero-Overhead**: No background servers, no open ports, no battery drain. Runs only when triggered and exits immediately upon submission.
- 🦉 **Night-Owl Aware Cycles**: Entries recorded between 00:00 AM and 04:59 AM are automatically attributed to the previous logical day.
- 📄 **Plain Text JSON Lines**: Data is appended line-by-line to `daily_logs.txt`. Easy to grep, backup, import into Obsidian/Notion, or parse with Python/jq.

---

## 🏛 Architecture

```
┌────────────────────────────────────────────────────────┐
│                   macOS launchd                        │
│          (Triggers daily at 02:00 AM / Wake)           │
└───────────────────────────┬────────────────────────────┘
                            │ Launches
                            ▼
┌────────────────────────────────────────────────────────┐
│                 SwiftUI Application                    │
│           (Floating NSWindow Prompt UI)                │
└───────────────────────────┬────────────────────────────┘
                            │ Subprocess IPC
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Python Backend                       │
│      (Validates, parses date cycle & appends)          │
└───────────────────────────┬────────────────────────────┘
                            │ Appends JSON record
                            ▼
┌────────────────────────────────────────────────────────┐
│                   daily_logs.txt                       │
│             (JSON Lines Text Database)                 │
└────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Prerequisites
- macOS (Apple Silicon or Intel)
- Swift 5.9+ / 6.0 (`xcode-select --install`)
- Python 3.8+

### 2. Automated Installation
Clone the repository and run the setup script:

```bash
git clone https://github.com/your-username/logger.git
cd logger
./setup.sh
```

The script compiles the release binary to `bin/DailyLoggerUI` and configures the macOS LaunchAgent.

### 3. Enable the Scheduled Trigger
Activate the background schedule:

```bash
launchctl load ~/Library/LaunchAgents/com.user.dailylogger.plist
```

To verify it is active:
```bash
launchctl list | grep com.user.dailylogger
```

---

## 💻 Usage

### Launching Manually / Testing the UI
Want to test the prompt right now without waiting for 2:00 AM?

```bash
./bin/DailyLoggerUI --force
```

### Shortcuts & Controls

| Action | Control |
| :--- | :--- |
| **Save & Dismiss** | `Cmd + Enter` or Click **"Save Log"** |
| **Dismiss without saving** | Click **"Dismiss"** |
| **Move Window** | Click and drag anywhere on the window background |

---

## 📊 Reading & Managing Logs

Your logs are stored in `daily_logs.txt` at the root of the project:

### View Recent Logs
```bash
# View last 10 entries formatted as JSON
python3 backend/logger.py list --limit 10 --reverse

# View the raw file
cat daily_logs.txt
```

### Check Today's Status
```bash
# Exits 0 if already logged, 1 if pending
./bin/DailyLoggerUI --check
```

### Add an Entry via Command Line
```bash
python3 backend/logger.py log --text "Shipped initial release of Daily Logger!"
```

### Sample Record (`daily_logs.txt`)
Each entry is an independent, single-line JSON object:
```json
{"id": "d2eb7c4d", "timestamp": "2026-10-24T00:30:15", "date": "2026-10-23", "entry": "Participating in the Developer Night Hackathon, had a lot of fun"}
```

---

## ⚙️ Configuration

You can customize behavior using environment variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `DAILY_LOG_FILE` | Custom path to the `.txt` database file | `<repo-root>/daily_logs.txt` |
| `LOGGER_PYTHON_PATH` | Path to a specific Python 3 interpreter | Auto-detected (`python3`) |
| `LOGGER_BACKEND_SCRIPT` | Path to `backend/logger.py` | Auto-detected relative to executable |

Example:
```bash
export DAILY_LOG_FILE="$HOME/Notes/daily_logs.txt"
```

---

## 🛑 Uninstallation

To disable and remove the scheduled LaunchAgent:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.dailylogger.plist
rm -f ~/Library/LaunchAgents/com.user.dailylogger.plist
```

---

## 🧪 Testing

Run the automated backend test suite:

```bash
python3 -m unittest backend/test_logger.py
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
