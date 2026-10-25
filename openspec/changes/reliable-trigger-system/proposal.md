# Proposal

## Why

The Daily Logger's scheduled 2:00 AM prompt silently fails to appear because the LaunchAgent is never registered with `launchd` during setup, the floating window is invisible when the user is on a different Space or in full-screen mode, and there is no fallback notification to alert the user. Additionally, the trigger time is hardcoded with no way to customize it, and there is no diagnostic command to verify the system is healthy.

## What Changes

- **Auto-register the LaunchAgent**: `setup.sh` will automatically load the plist into `launchd` instead of only printing a manual instruction.
- **Fix window visibility across Spaces and full-screen apps**: Add `canJoinAllSpaces` and `fullScreenAuxiliary` collection behaviors so the prompt appears on whichever desktop/Space the user is currently using.
- **Add native macOS notification banner**: Post a `UserNotifications` banner when the prompt fires. If the user misses or dismisses the floating window, the notification persists in Notification Center and clicking it brings the window to front.
- **Configurable trigger time**: Allow the user to set their preferred prompt hour/minute via a configuration file (`~/.dailylogger.json`) or environment variable, replacing the hardcoded 02:00 AM. The `setup.sh` and plist template will respect this configuration.
- **Add `--status` diagnostic command**: A new CLI flag that inspects whether the LaunchAgent is loaded, the plist is valid, today's log status, and recent error output — enabling quick self-diagnosis.

## Capabilities

### New Capabilities
- `trigger-reliability`: Covers the automatic registration of the LaunchAgent during setup, and the `--status` diagnostic command that verifies system health (launchd registration, plist validity, log file accessibility, recent run output).
- `notification-banner`: Covers posting native macOS `UserNotifications` banners alongside the floating prompt, notification permission handling, and click-to-focus behavior.
- `configurable-schedule`: Covers user-configurable trigger time (hour/minute) via `~/.dailylogger.json` or environment variable, plist generation from the configured time, and validation of the configuration.
- `window-visibility`: Covers reliable window presentation across all virtual Spaces and over full-screen applications.

### Modified Capabilities
_None (no existing specs)._

## Impact

- **`setup.sh`**: Adds `launchctl bootstrap`/`load` calls and reads schedule configuration.
- **`launchd/com.user.dailylogger.plist`**: Becomes a template; actual plist is generated from user configuration during setup.
- **`ui/Sources/DailyLogger/main.swift`**: Adds `--status` flag handling, notification posting, and window collection behavior changes.
- **`ui/Sources/DailyLogger/Views/FloatingPromptView.swift`**: No structural changes expected.
- **`ui/Sources/DailyLogger/Services/ProcessRunner.swift`**: May gain a `checkStatus()` method for `--status` diagnostics.
- **`ui/Package.swift`**: May need `UserNotifications` framework linkage.
- **New file `~/.dailylogger.json`**: User-facing configuration file for schedule preferences.
- **Dependencies**: `UserNotifications` framework (system framework, no third-party dependencies).
