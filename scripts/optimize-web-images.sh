#!/usr/bin/env bash
# Re-encode the home page's before/after comparison shots into the responsive
# WebP variants that apps/web/components/BeforeAfter.tsx references.
#
# Why this exists: the sources are 3456×2234 screenshots weighing ~5 MB each
# (and, despite the .jpg extension, they are PNGs — `file` them and see). Both
# were served raw and rel=preload'ed on /, so a first visit pulled 10.45 MB of
# images for a box CSS caps at 1240px. Next's <Image> optimizer is unavailable
# under `output: 'export'`, so the resizing happens here instead.
#
# Sizes: 1240 = the .ba container's max-width (globals.css), 2480 = the same at
# 2× DPR. The <img srcset> lets the browser pick; phones take the 1240w.
#
# Usage:  ./scripts/optimize-web-images.sh          (needs cwebp: brew install webp)
# Re-run after replacing either source screenshot, then commit the .webp files.

set -euo pipefail

PUBLIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/apps/web/public"
QUALITY=80
WIDTHS=(2480 1240)
SOURCES=(compare-normal compare-boosted)

command -v cwebp >/dev/null 2>&1 || {
  echo "error: cwebp not found — install it with: brew install webp" >&2
  exit 1
}

for name in "${SOURCES[@]}"; do
  src="$PUBLIC_DIR/$name.jpg"
  [ -f "$src" ] || { echo "error: missing source $src" >&2; exit 1; }

  for width in "${WIDTHS[@]}"; do
    out="$PUBLIC_DIR/$name-$width.webp"
    # -resize W 0 keeps the aspect ratio; -m 6 is the slowest/smallest setting.
    cwebp -q "$QUALITY" -resize "$width" 0 -m 6 -mt "$src" -o "$out" >/dev/null 2>&1
    printf '%-30s %6s KB\n' "$(basename "$out")" "$(( $(wc -c <"$out") / 1024 ))"
  done
done

echo
echo "Sources are left in place. They are no longer referenced by the site —"
echo "delete them once you are happy with the re-encodes:"
for name in "${SOURCES[@]}"; do echo "  apps/web/public/$name.jpg"; done
