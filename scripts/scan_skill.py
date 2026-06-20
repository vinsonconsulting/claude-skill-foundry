#!/usr/bin/env python3
"""Scan a skill's text/instruction surface with SkillSpector.

SkillSpector does static text analysis. A skill's bundled *binary* assets
(fonts, images, archives) are data, not instructions: feeding their bytes to the
scanner yields meaningless "Memory Poisoning" / "Tool Misuse" noise (a single
bundled .ttf font can score a clean skill as CRITICAL). The skill's generated
card/scan artifacts are likewise not source.

So this stages a text-only copy of the skill — UTF-8-decodable files, minus the
generated artifacts and VCS/build noise — and scans that. The exclusion set
matches Califa's content_hash, so "what is hashed" and "what is scanned" agree.

Usage:
    scan_skill.py <skill_dir> --json <out.json> [--sarif <out.sarif>]
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Generated artifacts + VCS/editor noise: not skill source, never scanned. Kept
# in lockstep with Califa's hashing.EXCLUDE_NAMES so the scanned surface matches
# the hashed surface — including the v0.4.0 sidecar (card.authored.yaml) and the
# review checklist (card-review.md), whose accept-and-note text would otherwise
# feed finding descriptions back into the scanner as fresh findings.
EXCLUDE_NAMES = {
    "skill-card.md", "card.json", "card-review.md", "card.authored.yaml",
    "scan.json", "report.json", "report.sarif", ".DS_Store",
}
EXCLUDE_DIR_PARTS = {"__pycache__", ".git"}


def _is_text(path: Path) -> bool:
    try:
        path.read_text(encoding="utf-8")
        return True
    except (UnicodeDecodeError, ValueError):
        return False


def stage_text_surface(skill_dir: Path, dest: Path) -> int:
    kept = 0
    for path in skill_dir.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(skill_dir)
        if path.name in EXCLUDE_NAMES:
            continue
        if any(part in EXCLUDE_DIR_PARTS for part in rel.parts):
            continue
        if not _is_text(path):
            continue
        out = dest / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, out)
        kept += 1
    return kept


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Scan a skill's text surface with SkillSpector.")
    parser.add_argument("skill_dir")
    parser.add_argument("--json", dest="json_out")
    parser.add_argument("--sarif", dest="sarif_out")
    args = parser.parse_args(argv)

    skill_dir = Path(args.skill_dir)
    if not args.json_out and not args.sarif_out:
        parser.error("at least one of --json / --sarif is required")

    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / skill_dir.name
        staged.mkdir()
        kept = stage_text_surface(skill_dir, staged)
        if kept == 0:
            print(f"warning: {skill_dir} has no text files to scan", file=sys.stderr)
        for fmt, out in (("json", args.json_out), ("sarif", args.sarif_out)):
            if not out:
                continue
            subprocess.run(
                ["skillspector", "scan", str(staged), "--no-llm", "--format", fmt, "--output", out],
                check=True,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
