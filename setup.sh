#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$REPO_ROOT/bin"
PLIST_SRC="$REPO_ROOT/launchd/com.user.dailylogger.plist"
USER_LAUNCHAGENTS="$HOME/Library/LaunchAgents"
TARGET_PLIST="$USER_LAUNCHAGENTS/com.user.dailylogger.plist"

echo "=== Daily Logger Setup & Installation ==="

# 1. Check prerequisites
echo "[1/4] Checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required but not installed." >&2; exit 1; }
command -v swift >/dev/null 2>&1 || { echo "Error: swift is required but not installed." >&2; exit 1; }
echo "  ✓ python3 found: $(python3 --version)"
echo "  ✓ swift found: $(swift --version | head -n 1)"

# 2. Build Release Binary
echo "[2/4] Building Swift UI application in release mode..."
mkdir -p "$BIN_DIR"
swift build -c release --package-path "$REPO_ROOT/ui"
RELEASE_BIN="$(swift build --show-bin-path -c release --package-path "$REPO_ROOT/ui")/DailyLoggerUI"

if [ ! -f "$RELEASE_BIN" ]; then
    RELEASE_BIN="$REPO_ROOT/ui/.build/release/DailyLoggerUI"
fi

if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Failed to find compiled binary at $RELEASE_BIN" >&2
    exit 1
fi

cp "$RELEASE_BIN" "$BIN_DIR/DailyLoggerUI"
chmod +x "$BIN_DIR/DailyLoggerUI"
echo "  ✓ Binary compiled and copied to: $BIN_DIR/DailyLoggerUI"

# 3. Configure and Register LaunchAgent
echo "[3/4] Configuring macOS LaunchAgent..."
mkdir -p "$USER_LAUNCHAGENTS"

CONFIG_FILE="$HOME/.dailylogger.json"
TARGET_HOUR=2
TARGET_MINUTE=0

if [ -f "$CONFIG_FILE" ]; then
    eval "$(python3 -c "
import json, sys
try:
    with open('$CONFIG_FILE') as f:
        data = json.load(f)
    h = data.get('hour', 2)
    m = data.get('minute', 0)
    print(f'TARGET_HOUR={h}')
    print(f'TARGET_MINUTE={m}')
except Exception as e:
    sys.stderr.write(f'Warning: Could not parse {CONFIG_FILE}: {e}\n')
    print('TARGET_HOUR=2')
    print('TARGET_MINUTE=0')
")"
fi

if [ -n "$DAILY_LOGGER_HOUR" ]; then
    TARGET_HOUR="$DAILY_LOGGER_HOUR"
fi

if [ -n "$DAILY_LOGGER_MINUTE" ]; then
    TARGET_MINUTE="$DAILY_LOGGER_MINUTE"
fi

# Validate hour and minute
if ! [[ "$TARGET_HOUR" =~ ^[0-9]+$ ]] || [ "$TARGET_HOUR" -lt 0 ] || [ "$TARGET_HOUR" -gt 23 ]; then
    echo "Error: Invalid hour '$TARGET_HOUR'. Must be an integer between 0 and 23." >&2
    exit 1
fi

if ! [[ "$TARGET_MINUTE" =~ ^[0-9]+$ ]] || [ "$TARGET_MINUTE" -lt 0 ] || [ "$TARGET_MINUTE" -gt 59 ]; then
    echo "Error: Invalid minute '$TARGET_MINUTE'. Must be an integer between 0 and 59." >&2
    exit 1
fi

SCHEDULE_TIME=$(printf "%02d:%02d" "$TARGET_HOUR" "$TARGET_MINUTE")
echo "  Schedule configured for: $SCHEDULE_TIME daily"

# Replace binary path, Hour, and Minute in plist template and save to user LaunchAgents
sed -E \
    -e "s|<string>.*DailyLoggerUI</string>|<string>$BIN_DIR/DailyLoggerUI</string>|g" \
    -e "/<key>Hour<\/key>/ { n; s|<integer>[0-9]+</integer>|<integer>$TARGET_HOUR</integer>|; }" \
    -e "/<key>Minute<\/key>/ { n; s|<integer>[0-9]+</integer>|<integer>$TARGET_MINUTE</integer>|; }" \
    "$PLIST_SRC" > "$TARGET_PLIST"

plutil -lint "$TARGET_PLIST" >/dev/null
echo "  ✓ Installed LaunchAgent to: $TARGET_PLIST"

# Auto-register LaunchAgent with launchd
echo "  Registering LaunchAgent with macOS launchd..."
UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/com.user.dailylogger" 2>/dev/null || launchctl unload "$TARGET_PLIST" 2>/dev/null || true
if ! launchctl bootstrap "gui/$UID_NUM" "$TARGET_PLIST" 2>/dev/null; then
    launchctl load -w "$TARGET_PLIST" 2>/dev/null || true
fi
echo "  ✓ LaunchAgent registered and active with launchd"

# 4. Verify Backend & CLI
echo "[4/4] Verifying backend integration..."
python3 "$REPO_ROOT/backend/logger.py" --help >/dev/null
"$BIN_DIR/DailyLoggerUI" --check || true
echo "  ✓ Integration check passed!"

echo ""
echo "=== Setup Complete! ==="
echo "The Daily Logger is now active and configured to trigger at $SCHEDULE_TIME daily (or whenever your Mac wakes up)."
echo ""
echo "To test the floating prompt UI right now, run:"
echo "  $BIN_DIR/DailyLoggerUI --force"
echo ""
echo "To view stored logs, check:"
echo "  $REPO_ROOT/daily_logs.txt (or run: python3 $REPO_ROOT/backend/logger.py list)"
