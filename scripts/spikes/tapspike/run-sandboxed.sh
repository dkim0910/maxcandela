#!/bin/bash
# Builds TapSpike as a sandboxed, ad-hoc-signed .app and runs it through
# LaunchServices, so macOS treats it as an app in its own right: its own
# sandbox container, its own "System Audio Recording" permission and prompt,
# showing its own NSAudioCaptureUsageDescription. (A bare binary started from
# Terminal is unsandboxed and its prompt is attributed to Terminal.)
#
#   ./run-sandboxed.sh list
#   ./run-sandboxed.sh <pid> <percent 0-200> <seconds> [--unmuted] [--crash]
#
#   ENTITLEMENTS=TapSpike-sandbox-only.entitlements ./run-sandboxed.sh …
#       control run without com.apple.security.device.audio-input
#
# Output is written to build/tapspike.log and printed when the run ends. If the
# log is empty (the sandbox refused the inherited file), read the unified log:
#   log show --last 5m --predicate 'subsystem == "com.maxcandela.tapspike"'
#
# The permission is keyed to the signature; an ad-hoc signature changes with
# every build, so expect the prompt again after rebuilding. To forget it:
#   tccutil reset AudioCapture com.maxcandela.tapspike
set -euo pipefail
cd "$(dirname "$0")"

ENTITLEMENTS="${ENTITLEMENTS:-TapSpike.entitlements}"
swift build -c release
APP="build/TapSpike.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TapSpike "$APP/Contents/MacOS/TapSpike"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP"
echo "Signed with $ENTITLEMENTS:"
codesign -d --entitlements - "$APP" 2>/dev/null | sed 's/^/  /'

LOG="$PWD/build/tapspike.log"
: > "$LOG"
open -W -n --stdout "$LOG" --stderr "$LOG" "$APP" --args "$@"
cat "$LOG"
