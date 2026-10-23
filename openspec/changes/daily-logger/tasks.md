# Tasks

## 1. Python Backend CLI & Storage

- [x] 1.1 Implement `backend/logger.py` supporting `log`, `has-logged`, and `list` commands that write and read JSON Lines in `daily_logs.txt`, and verify via CLI execution.
- [x] 1.2 Implement backend tests in `backend/test_logger.py` covering file creation, JSON-line appending, timestamp formatting, and `has-logged` logic, and verify with `python3 -m unittest`.

## 2. Swift Floating Window UI

- [x] 2.1 Set up the Swift package structure in `ui/` with `Package.swift` and verify it compiles with `swift build`.
- [x] 2.2 Implement `ProcessRunner` in Swift to execute the Python CLI via `Process()` and parse outputs, and verify with a test call.
- [x] 2.3 Implement the SwiftUI floating window view (`FloatingPromptView`) with prompt text, multi-line editor, "Save Log" and "Dismiss" buttons, and `Cmd+Enter` shortcut.
- [x] 2.4 Wire the window controller and launch flow to check `has-logged` before showing the window, and verify window dismissal after saving.

## 3. macOS LaunchAgent & Integration

- [x] 3.1 Create `launchd/com.user.dailylogger.plist` configured for 02:00 AM daily execution and validate syntax with `plutil -lint`.
- [x] 3.2 Provide a setup script (`setup.sh`) to build the Swift binary, configure environment paths, and verify the complete logging cycle from prompt to `daily_logs.txt`.
