#!/usr/bin/env bash
# Re-encode the home page's before/after comparison shots into the responsive
# WebP variants that apps/web/components/BeforeAfter.tsx references.
#
# Why this exists: the sources are 3456×2234 PNG screenshots weighing ~5 MB
# each. Both were served raw and rel=preload'ed on /, so a first visit pulled
# 10.45 MB of images for a box CSS caps at 1240px. Next's <Image> optimizer is
# unavailable under `output: 'export'`, so the resizing happens here instead.
#
# The sources live in assets/screenshots/, NOT in apps/web/public/. Everything
# under public/ is published verbatim, so a 5 MB master kept there is a live
# crawlable URL on maxcandela.com that no page links to — 10.45 MB of the
# deploy serving no one. Same reason the brand master sits in assets/brand/.
# They were also named .jpg while being PNGs; renamed to match reality.
#
# Sizes: 1240 = the .ba container's max-width (globals.css), 2480 = the same at
# 2× DPR. The <img srcset> lets the browser pick; phones take the 1240w.
#
# Usage:  ./scripts/optimize-web-images.sh          (needs cwebp: brew install webp)
# Re-run after replacing either source screenshot, then commit the .webp files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/assets/screenshots"
PUBLIC_DIR="$REPO_ROOT/apps/web/public"
QUALITY=80
WIDTHS=(2480 1240)
SOURCES=(compare-normal compare-boosted)

command -v cwebp >/dev/null 2>&1 || {
  echo "error: cwebp not found — install it with: brew install webp" >&2
  exit 1
}

for name in "${SOURCES[@]}"; do
  src="$SRC_DIR/$name.png"
  [ -f "$src" ] || { echo "error: missing source $src" >&2; exit 1; }

  for width in "${WIDTHS[@]}"; do
    out="$PUBLIC_DIR/$name-$width.webp"
    # -resize W 0 keeps the aspect ratio; -m 6 is the slowest/smallest setting.
    cwebp -q "$QUALITY" -resize "$width" 0 -m 6 -mt "$src" -o "$out" >/dev/null 2>&1
    printf '%-30s %6s KB\n' "$(basename "$out")" "$(( $(wc -c <"$out") / 1024 ))"
  done
done

echo
echo "Sources stay in assets/screenshots/ — they are the masters these .webp"
echo "files are re-encoded from, and they are outside public/ so they are not"
echo "published. Commit the regenerated .webp files."

