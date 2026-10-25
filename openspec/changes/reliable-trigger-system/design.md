# Design

## Context

The current system has a working SwiftUI prompt and Python backend, connected via subprocess IPC (see proposal.md – Why). The binary is at `ui/.build/release/DailyLoggerUI`, copied to `bin/DailyLoggerUI` by `setup.sh`. The plist template at `launchd/com.user.dailylogger.plist` is copied (with binary path substitution) to `~/Library/LaunchAgents/` during setup but never loaded. The Swift app uses `NSWindow` with `.floating` level and `NSApp.activate(ignoringOtherApps: true)` for presentation. The Package.swift targets macOS 13+ with swift-tools-version 5.9.

## Goals / Non-Goals

**Goals:**
- Make the trigger "just work" after running `setup.sh` — no manual `launchctl` step.
- Ensure the prompt is always visible to the user, regardless of Spaces or full-screen apps.
- Deliver a native macOS notification banner as a parallel alert channel.
- Let the user choose their preferred prompt time without editing plist XML.
- Provide a single `--status` command for self-diagnosis.

**Non-Goals:**
- Building a GUI preferences window or menu bar app — configuration stays file-based.
- Multi-trigger schedules (e.g. hourly reminders) — one trigger per day.
- Syncing configuration across devices.
- Notification actions beyond "click to focus the window" (no inline reply).

## Decisions

### D1: LaunchAgent registration uses `launchctl bootstrap` with `load` fallback

**Decision:** `setup.sh` will first attempt `launchctl bootstrap gui/$(id -u) <plist-path>` (the modern API), falling back to `launchctl load -w <plist-path>` on older macOS. Before loading, it will unload any existing instance with `launchctl bootout` / `launchctl unload`.

**Why over alternatives:**
- `launchctl bootstrap` is the recommended API since macOS 10.10 and is what Apple documents for programmatic registration. The `load`/`unload` subcommands are legacy but still work and provide backward compatibility.
- Alternative: require the user to run `launchctl load` manually (current approach). Rejected because it is the root cause of the bug — users miss the instruction.

### D2: Configuration stored in `~/.dailylogger.json`

**Decision:** A JSON file at `~/.dailylogger.json` with schema `{"hour": <0-23>, "minute": <0-59>}`. `setup.sh` reads it (falling back to defaults of `{"hour": 2, "minute": 0}`). Environment variables `DAILY_LOGGER_HOUR` and `DAILY_LOGGER_MINUTE` override the file values.

**Why JSON over alternatives:**
- The project already uses JSON Lines for data storage and JSON for subprocess IPC, so JSON is idiomatic.
- Alternative: YAML or TOML. Rejected because the config has only two fields — a full config language is unnecessary, and parsing YAML in bash is fragile.
- Alternative: plist format. Rejected because the user-facing config should not look like the system plist it generates.

### D3: Plist generation via `sed` substitution in `setup.sh`

**Decision:** The existing `launchd/com.user.dailylogger.plist` template keeps its `<integer>2</integer>` and `<integer>0</integer>` defaults. `setup.sh` reads the configured hour/minute and uses `sed` to substitute both the binary path (existing behavior) and the Hour/Minute integer values before writing to `~/Library/LaunchAgents/`.

**Why over alternatives:**
- Keeps the implementation in bash without adding a dependency (Python, `plutil`, etc.).
- Alternative: generate the plist entirely in Python. Rejected because setup should remain a single bash script with minimal dependencies.
- Alternative: use `defaults write` or `plutil -replace`. These work on existing plists, not templates, and are harder to make idempotent.

### D4: Window visibility via `collectionBehavior` and `orderFrontRegardless`

**Decision:** In `main.swift`, set `window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` and call `window.orderFrontRegardless()` instead of `window.makeKeyAndOrderFront(nil)`.

**Why:**
- `.canJoinAllSpaces` makes the window follow the user to their current Space.
- `.fullScreenAuxiliary` allows the window to overlay full-screen apps without triggering a Space switch.
- `orderFrontRegardless()` brings the window to front even when the app is not the active app (which is always the case when launched by `launchd`).
- This is standard AppKit practice for alert/prompt windows that must not be missed.

### D5: UserNotifications via `UNUserNotificationCenter`

**Decision:** Use the `UserNotifications` framework (available since macOS 10.14, well within the macOS 13+ target). The app will:
1. Request authorization (`.alert`, `.sound`, `.badge`) on first launch via `requestAuthorization`.
2. Post a notification with `UNMutableNotificationContent` immediately after showing the window.
3. Implement `UNUserNotificationCenterDelegate` to handle `didReceive` response — bring the window to front.
4. Remove delivered notifications after the user submits or dismisses the prompt.

**Why over alternatives:**
- `UserNotifications` is the modern Apple framework, replacing `NSUserNotification` (deprecated since macOS 10.14).
- Alternative: `NSUserNotification`. Rejected because it is deprecated and removed in recent SDKs.
- Alternative: third-party notification library. Rejected because a system framework already does exactly this.

**Entitlements:** No app sandbox entitlement is needed for `UserNotifications` when running as a command-line tool outside the App Store. The app is not sandboxed.

### D6: `--status` diagnostic implemented in Swift

**Decision:** Add a `--status` flag in `main.swift`'s argument parsing (alongside existing `--check` and `--force`). The status command will:
1. Run `launchctl print gui/<uid>/com.user.dailylogger` and parse the exit code to determine if the service is loaded.
2. Check if `~/Library/LaunchAgents/com.user.dailylogger.plist` exists and run `plutil -lint` on it.
3. Delegate to `ProcessRunner.shared.hasLogged()` for today's log status.
4. Check for `/tmp/DailyLogger.stdout.log` and `/tmp/DailyLogger.stderr.log` and report their last-modified timestamps.
5. Print a human-readable summary and exit with 0 (healthy) or 1 (issues found).

**Why in Swift over Python:**
- The `--status` flag is a natural extension of the existing `--check` and `--force` flags in the Swift binary. Users expect `DailyLoggerUI --status` to work alongside `DailyLoggerUI --check`.
- It needs to inspect `launchctl`, which is easier from the same process context.

## Risks / Trade-offs

- **[Risk] Notification permission denied** → The floating window remains the primary channel; notifications are a supplementary alert. The app degrades gracefully.
- **[Risk] `launchctl bootstrap` behavior varies across macOS versions** → The `load -w` fallback covers older systems. The `--status` diagnostic helps users identify registration issues.
- **[Risk] `sed`-based plist generation is fragile** → The template has a fixed, simple structure. `plutil -lint` validation after generation catches malformed output.
- **[Trade-off] `orderFrontRegardless()` is aggressive** → It may interrupt the user's current work, but this is intentional — the whole purpose is to prompt the user. The Dismiss button and Esc shortcut provide a quick exit.
- **[Trade-off] Config file at `~/.dailylogger.json` rather than in-repo** → Keeps per-user preferences separate from the repo (which may be shared or version-controlled). Users who want repo-local config can set `DAILY_LOGGER_HOUR`/`DAILY_LOGGER_MINUTE` in their shell profile.
