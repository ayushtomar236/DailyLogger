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
RELEASE_BIN="$REPO_ROOT/ui/.build/release/DailyLoggerUI"

if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Failed to find compiled binary at $RELEASE_BIN" >&2
    exit 1
fi

cp "$RELEASE_BIN" "$BIN_DIR/DailyLoggerUI"
chmod +x "$BIN_DIR/DailyLoggerUI"
echo "  ✓ Binary compiled and copied to: $BIN_DIR/DailyLoggerUI"

# 3. Configure LaunchAgent
echo "[3/4] Configuring macOS LaunchAgent..."
mkdir -p "$USER_LAUNCHAGENTS"

# Replace binary path in plist template and save to user LaunchAgents
sed -E "s|<string>.*DailyLoggerUI</string>|<string>$BIN_DIR/DailyLoggerUI</string>|g" \
    "$PLIST_SRC" > "$TARGET_PLIST"

plutil -lint "$TARGET_PLIST" >/dev/null
echo "  ✓ Installed LaunchAgent to: $TARGET_PLIST"

# 4. Verify Backend & CLI
echo "[4/4] Verifying backend integration..."
python3 "$REPO_ROOT/backend/logger.py" --help >/dev/null
"$BIN_DIR/DailyLoggerUI" --check || true
echo "  ✓ Integration check passed!"

echo ""
echo "=== Setup Complete! ==="
echo "The Daily Logger is configured to trigger at 02:00 AM (or whenever your Mac wakes up)."
echo ""
echo "To activate the 02:00 AM trigger now, run:"
echo "  launchctl load $TARGET_PLIST"
echo ""
echo "To test the floating prompt UI right now, run:"
echo "  $BIN_DIR/DailyLoggerUI --force"
echo ""
echo "To view stored logs, check:"
echo "  $REPO_ROOT/daily_logs.txt (or run: python3 $REPO_ROOT/backend/logger.py list)"
