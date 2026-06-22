#!/usr/bin/env python3
"""Generate the root README catalog and inject it into README.md.

Walks skills/ for SKILL.md files, reads `name`/`description` from the frontmatter
and the per-skill card.json (scan severity, trigger metrics), and writes a
catalog grouped by category between the SKILLS-INDEX markers. Each category
heading links to that category's README and each skill row links to its per-skill
README. Two badges are kept in sync from the same data: the skills-count badge
(SKILLS-COUNT markers) and the aggregate scan badge (SCANS markers). `--check`
(and therefore CI) fails when any of them drift.

Usage:
  python3 scripts/build_index.py            # write the catalog into README.md
  python3 scripts/build_index.py --check    # exit 1 if README.md is out of date
"""
from __future__ import annotations
import sys
from pathlib import Path

import cardkit
from skilltools import parse_frontmatter, iter_skill_files

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
README = ROOT / "README.md"
START = "<!-- SKILLS-INDEX:START -->"
END = "<!-- SKILLS-INDEX:END -->"
COUNT_START = "<!-- SKILLS-COUNT:START -->"
COUNT_END = "<!-- SKILLS-COUNT:END -->"
SCANS_START = "<!-- SCANS:START -->"
SCANS_END = "<!-- SCANS:END -->"
# Badge color (shields.io). Keep in step with the README badge row.
COUNT_COLOR = "2b7489"


def discover() -> list[tuple[str, str, str, Path]]:
    records = []
    for p in iter_skill_files(SKILLS_DIR):
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        name = (fm.get("name") or p.parent.name).strip()
        desc = (fm.get("description") or "").strip()
        rel = p.relative_to(SKILLS_DIR).parts
        category = rel[0] if len(rel) >= 3 else "uncategorized"
        records.append((category, name, desc, p.parent))
    return records


def render_index(rows: list[tuple[str, str, str, Path]]) -> str:
    if not rows:
        return "_No skills yet. Add one under `skills/<category>/<name>/SKILL.md`._"
    by_cat: dict[str, list[tuple[str, str, Path]]] = {}
    for category, name, desc, skill_dir in rows:
        by_cat.setdefault(category, []).append((name, desc, skill_dir))
    out: list[str] = []
    for category in sorted(by_cat):
        out.append(f"### [{category}](skills/{category}/README.md)\n")
        out.append(cardkit.skills_table(by_cat[category], from_dir=ROOT))
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def render_count_badge(n: int) -> str:
    """A static shields.io badge for the live skill count."""
    label = "skill" if n == 1 else "skills"
    return f"![{n} {label}](https://img.shields.io/badge/skills-{n}-{COUNT_COLOR})"


def render_scans_badge(rows: list[tuple[str, str, str, Path]]) -> str:
    """Aggregate scan posture across carded skills (worst severity wins)."""
    cards = [cardkit.load_card(d) for *_rest, d in rows]
    carded = [c for c in cards if c]
    order = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
    if not carded:
        return cardkit.shield("scans", "none carded", cardkit.DIM)
    worst = "LOW"
    for c in carded:
        sev = (c.get("scan") or {}).get("severity", "LOW")
        if order.index(sev) > order.index(worst):
            worst = sev
    all_low = all((c.get("scan") or {}).get("severity") == "LOW" for c in carded)
    tail = "all LOW" if all_low else f"worst {worst}"
    msg = f"{len(carded)}/{len(rows)} carded · {tail}"
    return cardkit.shield("scans", msg, cardkit.SEVERITY_COLOR.get(worst, cardkit.DIM))


def replace_between(text: str, start: str, end: str, payload: str, *, required: bool) -> str:
    """Swap the content between `start` and `end` markers for `payload`.

    Markers are kept on their own lines with the payload between them. When the
    markers are absent, raise (if required) or return the text unchanged.
    """
    if start not in text or end not in text:
        if required:
            raise SystemExit(
                "README.md is missing the index markers. Add these two lines "
                f"where the index should go:\n  {start}\n  {end}"
            )
        return text
    pre = text.split(start)[0]
    post = text.split(end, 1)[1]
    return f"{pre}{start}\n{payload}\n{end}{post}"


def main(argv: list[str]) -> int:
    check = "--check" in argv
    rows = discover()
    index_md = render_index(rows)
    count_md = render_count_badge(len(rows))
    scans_md = render_scans_badge(rows)
    current = README.read_text(encoding="utf-8") if README.exists() else ""
    # The catalog keeps a blank line around it (tables read better); the badges
    # sit inline in the badge row, so no surrounding blank lines for those.
    updated = replace_between(current, START, END, f"\n{index_md}", required=True)
    updated = replace_between(updated, COUNT_START, COUNT_END, count_md, required=False)
    updated = replace_between(updated, SCANS_START, SCANS_END, scans_md, required=False)
    if check:
        if updated != current:
            print("README.md catalog or badges are out of date. Run: make index")
            return 1
        print("Catalog and badges are up to date.")
        return 0
    README.write_text(updated, encoding="utf-8")
    print(f"Updated README.md catalog ({len(rows)} skills).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
