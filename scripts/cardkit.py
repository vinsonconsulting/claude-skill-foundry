#!/usr/bin/env python3
"""Render card-derived content into READMEs from each skill's card.json.

Reads the committed `card.json` (the canonical machine form) directly with the
standard library, so the README tooling stays dependency-free, on the same
footing as `build_index.py` and `skilltools.py`. A missing `card.json` means the
skill is not carded yet; callers render a "card pending" placeholder rather than
inventing values.

Shared by `build_index.py` (root catalog) and `render_skill_readmes.py`
(category tables + per-skill card blocks).
"""
from __future__ import annotations

import json
import os
from pathlib import Path, PurePosixPath
from urllib.parse import quote

from skilltools import parse_frontmatter, iter_skill_files

# shields.io named colors, one per SkillSpector severity band.
SEVERITY_COLOR = {
    "LOW": "brightgreen",
    "MEDIUM": "yellow",
    "HIGH": "orange",
    "CRITICAL": "red",
}
DIM = "555"          # neutral gray for non-severity badges

# Public R2 base serving the CI-published shields *endpoint* JSON, one object per
# metric (scan, trigger, tasks, signed, card; Califa SPEC §F/§G) — see BADGES.md.
# The per-skill badges are endpoint badges off this base, so each renders straight
# from the published card.json with no second source of truth.
BADGE_BASE = "https://pub-71c1a161b82140039deed518bba2d659.r2.dev"


# --- reading -----------------------------------------------------------------

def load_card(skill_dir: str | Path) -> dict | None:
    p = Path(skill_dir) / "card.json"
    if not p.exists():
        return None
    return json.loads(p.read_text(encoding="utf-8"))


def skill_name_map(skills_dir: Path) -> dict[str, Path]:
    """Map every skill's declared name to its directory (for sibling links)."""
    out: dict[str, Path] = {}
    for p in iter_skill_files(skills_dir):
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        name = (fm.get("name") or p.parent.name).strip()
        out[name] = p.parent
    return out


# --- small formatters --------------------------------------------------------

def _esc(s: str) -> str:
    return str(s).replace("|", "\\|").replace("\n", " ").strip()


def _pct(x) -> str:
    return f"{round(float(x) * 100)}%"


def _ratio(x) -> str:
    return f"{float(x):.2f}"


def _first_clause(text: str, cap: int = 160) -> str:
    """A short one-liner from a long trigger description, no fabrication."""
    text = (text or "").strip()
    for sep in (" — ", ". ", "; ", " - "):
        if sep in text:
            head = text.split(sep, 1)[0].strip()
            if 20 <= len(head) <= cap:
                return head
    return (text[:cap].rstrip() + "…") if len(text) > cap else text


def shield(label: str, message: str, color: str, href: str | None = None) -> str:
    url = (
        "https://img.shields.io/static/v1?"
        f"label={quote(label)}&message={quote(message)}&color={quote(color)}"
    )
    img = f"![{label}: {message}]({url})"
    return f"[{img}]({href})" if href else img


def endpoint_shield(name: str, metric: str, href: str | None = None) -> str:
    """A shields *endpoint* badge whose label, message, and color are read live
    from the CI-published JSON at ``<BADGE_BASE>/<name>/<metric>.json`` instead of
    being recomputed here. Beta cards yield a neutral grey ``n/a`` for the
    trigger/tasks metrics, which is still a valid badge to show."""
    json_url = f"{BADGE_BASE}/{name}/{metric}.json"
    url = f"https://img.shields.io/endpoint?url={quote(json_url, safe='')}"
    img = f"![{metric}]({url})"
    return f"[{img}]({href})" if href else img


def _relpath(target: Path, from_dir: Path) -> str:
    return os.path.relpath(target, from_dir).replace(os.sep, "/")


def skill_readme_link(skill_dir: Path, from_dir: Path) -> str:
    return str(PurePosixPath(_relpath(skill_dir, from_dir)) / "README.md")


# --- table cells (root catalog + category tables) ----------------------------

def scan_cell(card: dict | None) -> str:
    if not card or not card.get("scan"):
        return "—"
    s = card["scan"]
    return f"{s['severity']} ({s['score']}/100)"


def trigger_cell(card: dict | None) -> str:
    m = (card or {}).get("metrics")
    if not m:
        return "—"
    return f"P {_ratio(m['trigger_precision'])} / R {_ratio(m['trigger_recall'])}"


def summary_cell(card: dict | None, description: str) -> str:
    text = card["summary"] if (card and card.get("summary")) else _first_clause(description)
    return _esc(text)


def skills_table(rows: list[tuple[str, str, Path]], from_dir: Path) -> str:
    """rows: (name, description, skill_dir). Columns: Skill | What it does | Scan | Trigger."""
    out = ["| Skill | What it does | Scan | Trigger (P/R) |", "| --- | --- | --- | --- |"]
    for name, desc, skill_dir in sorted(rows):
        card = load_card(skill_dir)
        link = skill_readme_link(skill_dir, from_dir)
        out.append(
            f"| [`{name}`]({link}) | {summary_cell(card, desc)} | "
            f"{scan_cell(card)} | {trigger_cell(card)} |"
        )
    return "\n".join(out)


# --- per-skill blocks --------------------------------------------------------

def _pending(kind: str) -> str:
    return (
        f"_Skill card pending. This skill ships a `SKILL.md` but has no published "
        f"`card.json` yet, so the {kind} block fills in once it is carded._"
    )


def summary_line(card: dict | None) -> str:
    if not card or not card.get("summary"):
        return _pending("summary")
    return card["summary"]


def badges_block(card: dict | None) -> str:
    if not card:
        return _pending("badges")
    name = card["name"]
    # report.sarif is gitignored (regenerated by make check); link the scan badge
    # to the readable card view, which carries the Security section.
    out: list[str] = [endpoint_shield(name, "scan", href="skill-card.md")]
    # `status` (beta/stable) is not a SPEC §F metric and has no served endpoint,
    # so it stays a static badge.
    if card.get("status"):
        out.append(shield("status", str(card["status"]), "blue"))
    # trigger/tasks/card/signed are always shown; a beta card renders a neutral
    # grey "n/a" for the metrics it has not measured yet.
    out += [
        endpoint_shield(name, "trigger"),
        endpoint_shield(name, "tasks"),
        endpoint_shield(name, "card"),
        endpoint_shield(name, "signed"),
    ]
    return "\n".join(out)


def triggers_block(card: dict | None, skill_dir: Path, name_to_dir: dict[str, Path]) -> str:
    if not card:
        return _pending("triggers")
    t = card.get("triggers") or {}
    out: list[str] = []
    pos = t.get("positive") or []
    if pos:
        out.append("**Use it when**\n")
        out.extend(f"- {item}" for item in pos)
        out.append("")
    neg = t.get("negative") or []
    if neg:
        out.append("**Reach for a sibling instead when**\n")
        for n in neg:
            if isinstance(n, dict):
                prompt = n.get("prompt", "")
                target = name_to_dir.get(n.get("use_instead", ""))
                if target is not None:
                    rel = PurePosixPath(_relpath(target, skill_dir)) / "README.md"
                    out.append(f"- {prompt} → use [`{n['use_instead']}`]({rel})")
                else:
                    out.append(f"- {prompt} → {n.get('use_instead', '')}")
            else:
                out.append(f"- {n}")
        out.append("")
    return "\n".join(out).rstrip()


def metrics_block(card: dict | None, methodology_link: str) -> str:
    if not card:
        return _pending("metrics")
    s = card.get("scan") or {}
    m = card.get("metrics")
    if not m:
        line = f"Quality metrics are not published yet (status: {card.get('status', 'beta')})."
        if s:
            line += f" The security scan is {s['severity']} ({s['score']}/100)."
        return line
    rows = [
        ("Trigger precision", _ratio(m["trigger_precision"])),
        ("Trigger recall", _ratio(m["trigger_recall"])),
        ("Task completion", _pct(m["task_completion_rate"])),
        ("Eval pass rate", _pct(m["eval_pass_rate"])),
    ]
    if m.get("near_miss_precision") is not None:
        rows.append(("Near-miss precision", _ratio(m["near_miss_precision"])))
    rows.append(("Harness", m.get("harness", "")))
    if s:
        findings = s.get("findings") or []
        accepted = sum(1 for f in findings if isinstance(f, dict) and f.get("status") == "accepted")
        extra = f", {accepted} accepted" if accepted else ""
        rows.append(("Scan", f"{s['severity']} ({s['score']}/100){extra}"))
    table = ["| Metric | Value |", "| --- | --- |"]
    table += [f"| {k} | {_esc(v)} |" for k, v in rows]
    table.append("")
    table.append(f"See [what these numbers mean]({methodology_link}).")
    return "\n".join(table)
