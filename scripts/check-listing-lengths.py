#!/usr/bin/env python3
"""Check docs/app-store-listing.md against App Store Connect's field limits.

    python3 scripts/check-listing-lengths.py

Reads the fenced block under each limited heading and exits non-zero if any is
over. App Store Connect counts characters, not bytes, which is what len() does.
"""
import pathlib
import re
import sys

LIMITS = {
    "Name": 30,
    "Subtitle": 30,
    "Promotional text": 170,
    "Keywords": 100,
    "Description": 4000,
    "What's New in This Version": 4000,
    "App Review notes": 4000,
}

text = (pathlib.Path(__file__).resolve().parent.parent / "docs" / "app-store-listing.md").read_text()
failed = False
for field, limit in LIMITS.items():
    match = re.search(r"^## " + re.escape(field) + r"[^\n]*\n.*?```\n(.*?)\n```", text, re.S | re.M)
    if not match:
        print(f"MISSING  {field}")
        failed = True
        continue
    length = len(match.group(1))
    over = length > limit
    failed |= over
    print(f"{'OVER' if over else 'ok':7}  {field}: {length}/{limit}")
sys.exit(1 if failed else 0)
