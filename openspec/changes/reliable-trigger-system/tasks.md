# Tasks

## 1. Window Visibility Fix

- [x] 1.1 In `ui/Sources/DailyLogger/main.swift`, add `window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` in `showPromptWindow()` and replace `window.makeKeyAndOrderFront(nil)` with `window.orderFrontRegardless()`. Verify by building with `swift build -c release --package-path ui` and running `./ui/.build/release/DailyLoggerUI --force` while on a different Space or in a full-screen app — the prompt window must appear on the current Space and overlay full-screen content.

## 2. Notification Banner Integration

- [x] 2.1 Create `ui/Sources/DailyLogger/Services/NotificationManager.swift` implementing a `NotificationManager` class that wraps `UNUserNotificationCenter`: a `requestAuthorization()` method requesting `.alert`, `.sound`, `.badge` permissions, a `postPromptNotification()` method that posts a notification with title "Daily Reflection" and body "Time to log what you did today", and a `removeDeliveredNotifications()` method. Verify by building successfully with `swift build --package-path ui`.
- [x] 2.2 Implement `UNUserNotificationCenterDelegate` in `NotificationManager` so that `userNotificationCenter(_:didReceive:withCompletionHandler:)` calls `NSApp.activate(ignoringOtherApps: true)` and brings the window to front via `window.orderFrontRegardless()`. Verify by building successfully.
- [x] 2.3 Integrate `NotificationManager` into `main.swift`: call `requestAuthorization()` in `applicationDidFinishLaunching`, call `postPromptNotification()` in `showPromptWindow()`, and call `removeDeliveredNotifications()` in both the `onDismiss` and `onSaveSuccess` callbacks. Verify by running `./ui/.build/release/DailyLoggerUI --force` — a macOS notification banner must appear alongside the floating window. Granting and denying notification permission must both result in the floating window appearing normally.

## 3. Configurable Schedule

- [x] 3.1 Update `setup.sh` to read `~/.dailylogger.json` (if it exists) using `python3 -c "..."` inline to parse the JSON and extract `hour` and `minute` fields, defaulting to `2` and `0`. Check for `DAILY_LOGGER_HOUR` and `DAILY_LOGGER_MINUTE` environment variables that override the file values. Validate that hour is 0–23 and minute is 0–59; exit with an error message if invalid. Verify by creating `~/.dailylogger.json` with `{"hour": 22, "minute": 30}`, running `./setup.sh`, and confirming the installed plist at `~/Library/LaunchAgents/com.user.dailylogger.plist` contains `<integer>22</integer>` for Hour and `<integer>30</integer>` for Minute.
- [x] 3.2 Update the `sed` substitution in `setup.sh` to replace both the binary path (existing) and the `<integer>` values for Hour and Minute in the plist template. Verify by running `./setup.sh` with different hour/minute configurations and checking the installed plist with `plutil -p ~/Library/LaunchAgents/com.user.dailylogger.plist`.
- [x] 3.3 Document the configuration file format in `README.md` under a new "Schedule Configuration" subsection of the existing "Configuration" section. Verify the documented instructions produce a valid plist when followed.

## 4. LaunchAgent Auto-Registration

- [x] 4.1 Add a new step in `setup.sh` after copying the plist: unload any existing instance (`launchctl bootout gui/$(id -u)/com.user.dailylogger 2>/dev/null || launchctl unload ~/Library/LaunchAgents/com.user.dailylogger.plist 2>/dev/null || true`), then load the new one (`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.dailylogger.plist 2>/dev/null || launchctl load -w ~/Library/LaunchAgents/com.user.dailylogger.plist`). Verify by running `./setup.sh` and then confirming `launchctl list | grep dailylogger` shows the service as loaded.
- [x] 4.2 Update the setup completion message in `setup.sh` to state the schedule is now active (remove the manual `launchctl load` instruction). Verify the output message no longer tells the user to run `launchctl load` manually.

## 5. Status Diagnostic Command

- [x] 5.1 Add `--status` flag handling in the entry point section of `main.swift` (alongside `--check` and `--force`). Implement status checks: run `launchctl print gui/<uid>/com.user.dailylogger` via `Process` and report whether the service is loaded, check `~/Library/LaunchAgents/com.user.dailylogger.plist` existence, call `ProcessRunner.shared.hasLogged()` for today's log status, and check for `/tmp/DailyLogger.stdout.log` and `/tmp/DailyLogger.stderr.log` existence and last-modified dates. Print a human-readable summary. Exit 0 if healthy, 1 if issues found. Verify by running `./ui/.build/release/DailyLoggerUI --status` — it must report the current state of each component.
- [x] 5.2 Document the `--status` flag in `README.md` under the "Usage" section. Verify the documented command runs and produces output.

## 6. Integration Verification

- [x] 6.1 Run `./setup.sh` end-to-end on a clean state (unload existing LaunchAgent first), verify: the binary compiles, the plist is installed with the configured time, the LaunchAgent is loaded in `launchctl`, `DailyLoggerUI --status` reports all green, and `DailyLoggerUI --force` shows the prompt with a notification banner on the current Space.
