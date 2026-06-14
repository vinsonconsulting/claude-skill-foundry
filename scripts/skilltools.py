#!/usr/bin/env python3
"""Shared helpers for the skills tooling.

Dependency-free (stdlib only). The frontmatter parser handles the shapes used in
SKILL.md frontmatter: single-line `key: value`, quoted values, YAML plain
multi-line scalars (wrapped/indented continuation lines), and folded (`>`) or
literal (`|`) block scalars. It is not a full YAML implementation.
"""
from __future__ import annotations
from pathlib import Path


def _strip_quotes(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] in "\"'" and v[-1] == v[0]:
        return v[1:-1]
    return v


def parse_frontmatter(text: str) -> dict:
    """Pull top-level scalar keys from a leading --- frontmatter block."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    fm: dict[str, str] = {}
    i = 1
    cur_key = None
    block = None               # 'folded' | 'literal'
    block_lines: list[str] = []
    block_indent = None
    last_key = None

    def flush_block():
        nonlocal block, block_lines, block_indent, cur_key
        if block is not None and cur_key is not None:
            joiner = " " if block == "folded" else "\n"
            fm[cur_key] = joiner.join(block_lines).strip()
        block = None
        block_lines = []
        block_indent = None

    while i < len(lines):
        line = lines[i]
        if block is not None:
            if line.strip() == "" or line.startswith((" ", "\t")):
                if line.strip() == "":
                    block_lines.append("")
                else:
                    if block_indent is None:
                        block_indent = len(line) - len(line.lstrip())
                    block_lines.append(line[block_indent:])
                i += 1
                continue
            flush_block()

        stripped = line.strip()
        if stripped == "---":
            break
        if not stripped:
            i += 1
            continue

        indented = line.startswith((" ", "\t"))
        if not indented and ":" in line and not stripped.startswith("#"):
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            if val in (">", ">-", "|", "|-"):
                cur_key = key
                block = "folded" if val.startswith(">") else "literal"
                block_lines = []
                block_indent = None
                last_key = None
            else:
                fm[key] = _strip_quotes(val)
                last_key = key
            i += 1
            continue

        if indented and last_key is not None and not stripped.startswith("#"):
            sep = " " if fm.get(last_key) else ""
            fm[last_key] = (fm.get(last_key, "") + sep + stripped).strip()
            i += 1
            continue

        i += 1

    flush_block()
    return fm


def iter_skill_files(skills_dir: Path) -> list[Path]:
    """All SKILL.md under skills_dir, skipping meta/hidden paths.

    Any path component starting with '_' or '.' is ignored, so folders like
    `_TEMPLATE` and dotfiles never count as skills.
    """
    if not skills_dir.is_dir():
        return []
    out: list[Path] = []
    for p in sorted(skills_dir.rglob("SKILL.md")):
        rel_parts = p.relative_to(skills_dir).parts
        if any(part.startswith(("_", ".")) for part in rel_parts):
            continue
        out.append(p)
    return out
