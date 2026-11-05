#!/usr/bin/env python3
"""Sanitize n8n workflow exports before they are committed.

Usage: n8n_sanitize_export.py <input_dir> <output_dir>

For every *.json file in <input_dir> (output of `n8n export:workflow --separate`):
  * refuse the whole run if the file contains something that looks like a secret,
  * drop runtime/test data keys (pinData, staticData),
  * write <output_dir>/<slug-of-workflow-name>.json (pretty-printed, stable key order).

Exit codes: 0 = ok, 1 = secret-like content found, 2 = usage / input error.
"""

import json
import re
import sys
from pathlib import Path

DROP_KEYS = ("pinData", "staticData")

SECRET_PATTERNS = {
    "GitHub token": re.compile(r"\b(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{20,}"),
    "GitHub fine-grained token": re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    "Slack token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    "Slack webhook URL": re.compile(
        r"hooks\.slack\.com/services/T[A-Z0-9]{8,}/B[A-Z0-9]{8,}/[A-Za-z0-9]{20,}"
    ),
    "Bearer token": re.compile(r"[Bb]earer\s+[A-Za-z0-9._\-]{20,}"),
    "Private key": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
}


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return slug or "workflow"


def find_secrets(text: str) -> list[str]:
    return [label for label, pattern in SECRET_PATTERNS.items() if pattern.search(text)]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    in_dir, out_dir = Path(argv[1]), Path(argv[2])
    if not in_dir.is_dir():
        print(f"[ERROR] Input directory not found: {in_dir}", file=sys.stderr)
        return 2

    files = sorted(in_dir.glob("*.json"))
    if not files:
        print(f"[ERROR] No .json files in {in_dir}", file=sys.stderr)
        return 2

    # Pass 1: validate everything before writing anything
    parsed = []
    problems = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            print(f"[ERROR] {path.name}: invalid JSON ({exc})", file=sys.stderr)
            return 2
        for label in find_secrets(text):
            problems.append((path.name, label))
        parsed.append((path, data))

    if problems:
        for filename, label in problems:
            print(f"[ERROR] {filename}: looks like it contains a secret ({label}) - nothing written", file=sys.stderr)
        print("[ERROR] Move the secret into an n8n credential and export again.", file=sys.stderr)
        return 1

    # Pass 2: write sanitized files
    out_dir.mkdir(parents=True, exist_ok=True)
    seen = set()
    for path, data in parsed:
        # n8n export may wrap workflows in a list
        items = data if isinstance(data, list) else [data]
        for item in items:
            for key in DROP_KEYS:
                item.pop(key, None)
            slug = slugify(str(item.get("name", path.stem)))
            if slug in seen:
                slug = f"{slug}-{str(item.get('id', path.stem)).lower()}"
            seen.add(slug)
            target = out_dir / f"{slug}.json"
            target.write_text(
                json.dumps(item, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            print(f"[ OK ] {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
