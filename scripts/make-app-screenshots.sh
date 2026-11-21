#!/bin/bash
# App Store screenshots from the REAL menus.
#
#   scripts/make-app-screenshots.sh
#
# 1. Builds the debug app and, once per shot, runs it in screenshot mode
#    (MAXCANDELA_SHOT — see the bottom of MenuBarController.swift): the app
#    covers the whole screen with an opaque backdrop, opens one real menu on
#    top of it and reports where it is. `screencapture -R` then grabs exactly
#    that rectangle, so none of your desktop can be in the picture.
#    Each shot blanks the screen for about six seconds.
# 2. scripts/make-app-screenshots.swift composes the captures into 2880x1800
#    App Store screenshots with a caption each.
#
# Needs Screen Recording permission for the terminal running it. Quit any
# running MaxCandela first — this script stops dev builds, not the store copy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/assets/screenshots/store/raw"
OUT="$ROOT/assets/screenshots/store"
MARGIN=44   # room for the menu's shadow

mkdir -p "$RAW"
cd "$ROOT/apps/macos"
swift build >/dev/null
BIN="$ROOT/apps/macos/.build/debug/MaxCandela"
pkill -f 'debug/MaxCandela' 2>/dev/null || true
sleep 1

for shot in main WindowSnapTool ClipboardTool GeneratorTool WorldClockTool KeepAwakeTool; do
  frame="$(mktemp -t maxcandela-shot)"
  rm -f "$frame"
  MAXCANDELA_FORCE_TRIAL=licensed MAXCANDELA_SHOT="$shot" MAXCANDELA_SHOT_OUT="$frame" "$BIN" >/dev/null 2>&1 &
  pid=$!
  for _ in $(seq 1 60); do [ -s "$frame" ] && break; sleep 0.1; done
  if [ -s "$frame" ]; then
    # `|| true`: the file has no trailing newline, so read reports EOF.
    read -r x y w h < "$frame" || true
    sleep 0.4   # let the menu finish fading in
    screencapture -x -R "$((x - MARGIN)),$((y - MARGIN / 2)),$((w + MARGIN * 2)),$((h + MARGIN * 2))" "$RAW/$shot.png"
    echo "captured $shot (${w}x${h} pt)"
  else
    echo "no menu reported for $shot" >&2
  fi
  wait "$pid" 2>/dev/null || true
  rm -f "$frame"
done

swift "$ROOT/scripts/make-app-screenshots.swift" "$RAW" "$OUT"
