#!/usr/bin/env python3
"""Generate the README hero: an ASCII filing-cabinet banner, light + dark.

The repo hosts the ascii category, so the hero is itself ASCII art rather than a
raster image. Output is two SVGs (``hero-light.svg`` / ``hero-dark.svg``) wrapped
in a ``<picture>`` in the README: GitHub proxies ``<img>``-referenced SVGs through
camo and strips ``<style>`` media queries, so a single theme-aware SVG will not
switch on dark mode. Two files plus a ``(prefers-color-scheme: dark)`` source do.

Run:  python3 assets/generate_hero.py
"""

from __future__ import annotations

from pathlib import Path

LABELS = [
    "JIM'S FILING CABINET",
    "of CLAUDE SKILLS",
    "clone · copy a folder · done",
]
HANDLE = "[o]"  # drawer pull (ASCII only, so it is width-1 in every monospace font)
PAD = 2  # spaces of padding inside each drawer line, each side


def _drawer_box() -> list[str]:
    hw = len(HANDLE)
    inner = max(len(s) for s in LABELS) + PAD * 2 + hw + 2  # +2 = min label/handle gap
    top = "┌" + "─" * inner + "┐"
    sep = "├" + "─" * inner + "┤"
    bot = "└" + "─" * inner + "┘"
    rows: list[str] = [top]
    for i, label in enumerate(LABELS):
        body = " " * PAD + label
        gap = inner - len(body) - hw - PAD  # right-align the handle, keep right pad
        rows.append("│" + body + " " * gap + HANDLE + " " * PAD + "│")
        rows.append(sep if i < len(LABELS) - 1 else bot)
    return rows


def _frame(drawer: list[str]) -> list[str]:
    width = len(drawer[0])
    margin = 3
    inner = width + margin * 2
    top = "╔" + "═" * inner + "╗"
    bot = "╚" + "═" * inner + "╝"
    blank = "║" + " " * inner + "║"
    side = lambda r: "║" + " " * margin + r + " " * margin + "║"
    return [top, blank, *[side(r) for r in drawer], blank, bot]


def _svg(lines: list[str], ink: str) -> str:
    fs = 24
    cw = fs * 0.6
    lh = fs * 1.34
    pad = 28
    cols = max(len(s) for s in lines)
    w = round(cols * cw + pad * 2)
    h = round(len(lines) * lh + pad * 2)
    font = "'SFMono-Regular','SF Mono',Menlo,Consolas,'DejaVu Sans Mono',monospace"
    tspans = []
    for i, line in enumerate(lines):
        y = round(pad + fs + i * lh)
        esc = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        tspans.append(f'<tspan x="{pad}" y="{y}" xml:space="preserve">{esc}</tspan>')
    body = "\n    ".join(tspans)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}" role="img" '
        f'aria-label="Jim\'s Filing Cabinet of Claude Skills">\n'
        f'  <text font-family="{font}" font-size="{fs}" '
        f'fill="{ink}" letter-spacing="0">\n    {body}\n  </text>\n</svg>\n'
    )


def main() -> None:
    art = _frame(_drawer_box())
    out = Path(__file__).resolve().parent
    (out / "hero-light.svg").write_text(_svg(art, "#1f2328"), encoding="utf-8")
    (out / "hero-dark.svg").write_text(_svg(art, "#e6edf3"), encoding="utf-8")
    print("\n".join(art))
    print(f"\nwrote {out/'hero-light.svg'} and {out/'hero-dark.svg'}")


if __name__ == "__main__":
    main()
