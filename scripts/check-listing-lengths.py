#!/usr/bin/env python3
"""Check an App Store listing draft against App Store Connect's field limits.

    python3 scripts/check-listing-lengths.py                       # docs/app-store-listing.md
    python3 scripts/check-listing-lengths.py docs/app-store-listing-localized.md

Reads the fenced block under each limited heading and exits non-zero if any is
over. App Store Connect counts characters, not bytes, which is what len() does
— so a Japanese keyword field gets 100 characters, not 100 bytes.

Two layouts are understood:
  - the English listing: one `## <Field>` heading per field, every field
    required;
  - the localized file: a `## <Language>` heading per locale, with
    `### <Field>` headings under it for the fields that locale carries.
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
# What every localization must carry (Name and review notes are shared).
LOCALIZED_FIELDS = ["Subtitle", "Keywords", "Promotional text", "Description",
                    "What's New in This Version"]

root = pathlib.Path(__file__).resolve().parent.parent
path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / "docs" / "app-store-listing.md"
text = path.read_text()
failed = False


def block_after(heading_re, body):
    match = re.search(heading_re + r"[^\n]*\n.*?```\n(.*?)\n```", body, re.S | re.M)
    return match.group(1) if match else None


def check(label, field, value):
    global failed
    if value is None:
        print(f"MISSING  {label}{field}")
        failed = True
        return
    limit = LIMITS[field]
    over = len(value) > limit
    failed |= over
    print(f"{'OVER' if over else 'ok':7}  {label}{field}: {len(value)}/{limit}")


if re.search(r"^### ", text, re.M):
    # Localized layout: split on the level-2 locale headings.
    sections = re.split(r"^## (.+)$", text, flags=re.M)
    for name, body in zip(sections[1::2], sections[2::2]):
        if not re.search(r"^### ", body, re.M):
            continue
        for field in LOCALIZED_FIELDS:
            check(f"[{name.strip()}] ", field, block_after(r"^### " + re.escape(field), body))
else:
    for field in LIMITS:
        check("", field, block_after(r"^## " + re.escape(field), text))

sys.exit(1 if failed else 0)
