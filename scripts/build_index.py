#!/usr/bin/env python3
"""Generate the skills index and inject it into README.md.

Walks skills/ for SKILL.md files, reads `name` and `description` from the
frontmatter, and writes a Markdown table grouped by top-level category between
the SKILLS-INDEX markers in README.md.

Usage:
  python3 scripts/build_index.py            # write the index into README.md
  python3 scripts/build_index.py --check    # exit 1 if README.md is out of date
"""
from __future__ import annotations
import sys
from pathlib import Path

from skilltools import parse_frontmatter, iter_skill_files

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
README = ROOT / "README.md"
START = "<!-- SKILLS-INDEX:START -->"
END = "<!-- SKILLS-INDEX:END -->"


def discover() -> list[tuple[str, str, str, str]]:
    records = []
    for p in iter_skill_files(SKILLS_DIR):
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        name = (fm.get("name") or p.parent.name).strip()
        desc = (fm.get("description") or "").strip()
        rel = p.relative_to(SKILLS_DIR).parts
        category = rel[0] if len(rel) >= 3 else "uncategorized"
        path_display = p.parent.relative_to(ROOT).as_posix()
        records.append((category, name, desc, path_display))
    return records


def render_index() -> str:
    rows = discover()
    if not rows:
        return "_No skills yet. Add one under `skills/<category>/<name>/SKILL.md`._"
    by_cat: dict[str, list[tuple[str, str, str]]] = {}
    for category, name, desc, path in rows:
        by_cat.setdefault(category, []).append((name, desc, path))
    out: list[str] = []
    for category in sorted(by_cat):
        out.append(f"### {category}\n")
        out.append("| Skill | Description | Path |")
        out.append("| --- | --- | --- |")
        for name, desc, path in sorted(by_cat[category]):
            d = desc.replace("|", "\\|").replace("\n", " ")
            out.append(f"| `{name}` | {d} | `{path}/` |")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def inject(readme_text: str, index_md: str) -> str:
    if START not in readme_text or END not in readme_text:
        raise SystemExit(
            "README.md is missing the index markers. Add these two lines "
            f"where the index should go:\n  {START}\n  {END}"
        )
    pre = readme_text.split(START)[0]
    post = readme_text.split(END, 1)[1]
    return f"{pre}{START}\n\n{index_md}\n{END}{post}"


def main(argv: list[str]) -> int:
    check = "--check" in argv
    index_md = render_index()
    current = README.read_text(encoding="utf-8") if README.exists() else ""
    updated = inject(current, index_md)
    if check:
        if updated != current:
            print("README.md skills index is out of date. Run: make index")
            return 1
        print("Skills index is up to date.")
        return 0
    README.write_text(updated, encoding="utf-8")
    print("Updated README.md skills index.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
