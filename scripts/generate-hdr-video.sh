#!/usr/bin/env bash
# Generates the tiny HDR white video clips the web app plays to unlock EDR
# brightness in the browser. Requires ffmpeg (brew install ffmpeg).
#
# Output (committed to the repo so the site works without ffmpeg):
#   apps/web/public/hdr/white-pq.mp4   — HEVC 10-bit, BT.2020 + PQ (Safari)
#   apps/web/public/hdr/white-hlg.webm — VP9 10-bit, BT.2020 + HLG (Chrome)
#
# The clips are 64x64 solid white, 1s, looped by the <video> element. HDR
# metadata (color primaries/transfer) is what makes the browser engage EDR —
# the pixel content just needs to be at/near peak white.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/apps/web/public/hdr"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "error: ffmpeg not found. Install it with: brew install ffmpeg" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

echo "Generating HEVC PQ clip (Safari)…"
# 10-bit white in PQ: signal value 940 (10-bit full-range white in limited
# range terms is handled by ffmpeg's scale); we just feed a white source and
# tag BT.2020/PQ so the browser treats it as HDR peak white.
ffmpeg -y -loglevel error \
    -f lavfi -i "color=c=white:s=64x64:d=1:r=30,format=yuv420p10le" \
    -c:v libx265 -preset fast -crf 18 \
    -pix_fmt yuv420p10le \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -x265-params "hdr10=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400" \
    -tag:v hvc1 -movflags +faststart -an \
    "$OUT_DIR/white-pq.mp4"

echo "Generating VP9 HLG clip (Chrome/Firefox)…"
# setparams stamps the HLG metadata onto the frames themselves — libvpx only
# writes the WebM Colour element when the input frames carry it.
ffmpeg -y -loglevel error \
    -f lavfi -i "color=c=white:s=64x64:d=1:r=30,format=yuv420p10le,setparams=color_primaries=bt2020:color_trc=arib-std-b67:colorspace=bt2020nc" \
    -c:v libvpx-vp9 -b:v 0 -crf 20 \
    -pix_fmt yuv420p10le \
    -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc \
    -an \
    "$OUT_DIR/white-hlg.webm"

echo "Done:"
ls -lh "$OUT_DIR"
