#!/usr/bin/env python3
"""Fill card-derived regions in category and per-skill READMEs.

For each category README (`skills/<category>/README.md`) this fills the
`catalog` markers with that category's skills table. For each per-skill README
(`skills/<category>/<name>/README.md`) it fills the `badges`, `triggers`, and
`metrics` markers from the skill's card.json. Authored prose outside the markers
is never touched, and re-running is a no-op when everything is in sync.

Files that do not exist yet, or that lack a given marker pair, are left alone, so
this is safe to run at any phase of the README cascade. A skill with no card.json
gets a "card pending" placeholder rather than invented values.

Usage:
  python3 scripts/render_skill_readmes.py            # fill the markers in place
  python3 scripts/render_skill_readmes.py --check    # exit 1 if anything drifts
"""
from __future__ import annotations
import sys
import os
from pathlib import Path

import cardkit
from skilltools import iter_skill_files

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
README_NAME = "README.md"
METHODOLOGY_ANCHOR = "#how-these-are-built"

CATALOG = ("<!-- catalog:begin -->", "<!-- catalog:end -->")
CARD_MARKERS = {
    "summary": ("<!-- card:begin summary -->", "<!-- card:end summary -->"),
    "badges": ("<!-- card:begin badges -->", "<!-- card:end badges -->"),
    "triggers": ("<!-- card:begin triggers -->", "<!-- card:end triggers -->"),
    "metrics": ("<!-- card:begin metrics -->", "<!-- card:end metrics -->"),
}


def replace_between(text: str, start: str, end: str, payload: str) -> str:
    """Swap content between markers; leave text unchanged if either is absent."""
    if start not in text or end not in text:
        return text
    pre = text.split(start)[0]
    post = text.split(end, 1)[1]
    return f"{pre}{start}\n{payload}\n{end}{post}"


def _methodology_link(skill_dir: Path) -> str:
    rel = os.path.relpath(ROOT / README_NAME, skill_dir).replace(os.sep, "/")
    return f"{rel}{METHODOLOGY_ANCHOR}"


def skill_dirs_by_category() -> dict[str, list[tuple[str, str, Path]]]:
    from skilltools import parse_frontmatter
    by_cat: dict[str, list[tuple[str, str, Path]]] = {}
    for p in iter_skill_files(SKILLS_DIR):
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        name = (fm.get("name") or p.parent.name).strip()
        desc = (fm.get("description") or "").strip()
        rel = p.relative_to(SKILLS_DIR).parts
        category = rel[0] if len(rel) >= 3 else "uncategorized"
        by_cat.setdefault(category, []).append((name, desc, p.parent))
    return by_cat


def render(check: bool) -> int:
    by_cat = skill_dirs_by_category()
    name_to_dir = cardkit.skill_name_map(SKILLS_DIR)
    changes: list[str] = []

    def apply(path: Path, new_text: str) -> None:
        old = path.read_text(encoding="utf-8")
        if new_text == old:
            return
        changes.append(str(path.relative_to(ROOT)))
        if not check:
            path.write_text(new_text, encoding="utf-8")

    for category, rows in by_cat.items():
        cat_readme = SKILLS_DIR / category / README_NAME
        if cat_readme.exists():
            table = cardkit.skills_table(rows, from_dir=cat_readme.parent)
            text = cat_readme.read_text(encoding="utf-8")
            text = replace_between(text, CATALOG[0], CATALOG[1], f"\n{table}\n")
            apply(cat_readme, text)
        for _name, _desc, skill_dir in rows:
            skill_readme = skill_dir / README_NAME
            if not skill_readme.exists():
                continue
            card = cardkit.load_card(skill_dir)
            blocks = {
                "summary": cardkit.summary_line(card),
                "badges": cardkit.badges_block(card),
                "triggers": cardkit.triggers_block(card, skill_dir, name_to_dir),
                "metrics": cardkit.metrics_block(card, _methodology_link(skill_dir)),
            }
            text = skill_readme.read_text(encoding="utf-8")
            for key, (start, end) in CARD_MARKERS.items():
                text = replace_between(text, start, end, f"\n{blocks[key]}\n")
            apply(skill_readme, text)

    if check:
        if changes:
            print("Card-derived README blocks are out of date:")
            for c in changes:
                print(f"  - {c}")
            print("Run: python3 scripts/render_skill_readmes.py")
            return 1
        print("Category and per-skill card blocks are up to date.")
        return 0
    print(f"Rendered card blocks ({len(changes)} file(s) updated).")
    return 0


def main(argv: list[str]) -> int:
    return render("--check" in argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
