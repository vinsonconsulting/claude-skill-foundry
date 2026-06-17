# Jim's Filing Cabinet of Claude Skills

A filing cabinet for skills: small, self-contained capability folders that an LLM
(Claude in particular) loads on demand. Each skill is a directory under `skills/`
with a `SKILL.md` and whatever scripts, references, or assets it needs.

Built to be Claude-optimized and plainly usable anywhere. Clone the repo, copy the
folder you want, done.

[![validate](https://github.com/vinsonconsulting/jims-filing-cabinet-of-claude-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/vinsonconsulting/jims-filing-cabinet-of-claude-skills/actions/workflows/validate.yml)
![license](https://img.shields.io/badge/license-MIT-blue)

## Layout

```
skills/<category>/<skill-name>/SKILL.md
```

`SKILL.md` carries YAML frontmatter with a `name` and a `description`. The
description is what a model reads to decide whether to load the skill, so keep it
specific about when to use it, not just what it does.

## Skills

<!-- SKILLS-INDEX:START -->

### ascii_art

| Skill | Description | Path |
| --- | --- | --- |
| `ascii-img-react` | Use when rendering images as ASCII art in the browser or a React app with the ascii-img-react library — the shape-vector (not brightness-ramp) approach that keeps edges sharp. Trigger when ascii-img-react or <AsciiImage> is named; when the user wants an image-to-ASCII React component, a terminal/retro ASCII image effect on a web page, a click-ripple or rain ASCII animation over an image, or to theme ASCII output via CSS variables; or when they reach for the low-level utilities (sampleCell, sampleGrid, sampleExternalCircles, findBestCharacter, CachedCharacterLookup, applyGlobalContrast / applyDirectionalContrast, NORMALIZED_CHARACTERS). Covers install, the <AsciiImage> props, CORS/sizing/performance caveats, CSS-variable theming, Astro/Next integration, and the 6D shape-vector technique it implements. Not for converting an image file to ASCII from the command line in Python (use image-to-ascii), and not for real-time generative textmode graphics on a WebGL grid (use textmode-js). | `skills/ascii_art/ascii-img-react/` |
| `image-to-ascii` | Use when converting an image file to ASCII art outside the browser — a command-line or script run that turns a photo, logo, screenshot, or render into text, saved as .txt or rendered to .png/.svg. Trigger on "make ASCII art of this image/photo/cat", "convert this picture/logo to ASCII", "turn this PNG into an ASCII text file for my README", batch-converting a folder of images to ASCII, or any Python/Pillow image-to-ASCII task. Produces sharp, shape-aware output by matching each cell to the glyph whose shape fits best (6D shape vectors + nearest-neighbour, optional contrast enhancement) rather than a naive brightness ramp, and bundles a monospace font for deterministic results. Runs scripts/image_to_ascii.py. Not for ASCII graphics on a web page or in React (use ascii-img-react), not the real-time textmode.js library (use textmode-js), and not figlet-style text banners (this converts images, not words). | `skills/ascii_art/image-to-ascii/` |
| `textmode-js` | Use when building real-time ASCII or textmode graphics in the browser with the textmode.js library — generative glyph-grid sketches, retro/terminal visuals, audio-reactive or VJ textmode, or turning images and video into ASCII on a WebGL2 character grid. Trigger whenever textmode.js is named, when a sketch calls textmode.create, t.setup/t.draw, t.grid, t.char/charColor/cellColor, glyph ramps, or character-cell rendering, or when the user wants to build, debug, or export a grid-of-characters visual. Covers UMD/ESM setup, the setup/draw/resize lifecycle, drawing primitives, char and color cells, print and glyph ramps, animation and noise, layers, filters, custom GLSL ES 3.00 shaders, media conversion, and export to TXT/SVG/PNG/GIF/MP4/WebM. Not for generic ASCII art or Python image-to-ASCII — this is specifically the textmode.js JavaScript/TypeScript library. | `skills/ascii_art/textmode-js/` |

### tui

| Skill | Description | Path |
| --- | --- | --- |
| `bubbletea` | Use this skill when building a terminal UI (TUI) in Go with Bubble Tea and the Charm stack — the Elm Architecture / MVU pattern (`tea.Model` with `Init`/`Update`/`View`), `Cmd`/`Msg` event flow, Lip Gloss styling and layout, Bubbles components (`viewport`, `list`, `table`, `textinput`, `textarea`, `spinner`, `progress`), Glamour markdown rendering, and teatest for testing. Especially apt for streaming tokens from an LLM/agent into a terminal (goroutine → `p.Send` → `Update` → `viewport`), an agentic CLI, or any interactive full-screen or inline terminal app in Go. Targets v2 on the `charm.land/*/v2` import paths (Go 1.25+); writes current-version-correct code and avoids v1/beta patterns. Not for: Rust TUIs (→ Ratatui sibling), Python TUIs (→ Textual sibling), plain non-interactive CLI output (use `fmt`/`cobra`/standalone `lipgloss`), web/GUI UIs, or agent session orchestration / tmux / process multiplexing. | `skills/tui/bubbletea/` |
| `ratatui` | Use this skill for any task involving a Rust terminal/text user interface (TUI) built with Ratatui (or crossterm) — creating one, or debugging, fixing, testing, or extending an existing one. Covers: scaffolding the initial `main`/render loop and terminal setup; fixing teardown so a panic or crash doesn't leave the terminal in raw mode / broken; laying out panels, sidebars, status bars, dashboards, and popups with Layout/Constraint; wiring widgets like List, Table, Gauge, Chart, Scrollbar (including selection/scroll state that won't move); styling, text wrapping, and Unicode width issues; streaming LLM/async output into a terminal; and unit-testing rendered output without a real terminal. Triggers on "rust + terminal app/UI/dashboard", ratatui, crossterm. Writes current Ratatui 0.30+ code, not stale tui-rs patterns. Not for: Go TUIs (Bubble Tea), Python TUIs (Textual), non-interactive CLI output or progress bars, web/browser UIs, image-to-ASCII art (ascii/textmode), or tmux/agent-session orchestration. | `skills/tui/ratatui/` |
| `textual` | Use this skill when building or debugging a Python terminal UI (TUI) with Textual (Textualize's framework) — `App`/`Screen`/`Widget`, `compose()`, `reactive`/`watch_`, `@work` workers, Textual CSS / TCSS (`dock`, `grid`, `fr` units), widgets like `RichLog`, `Markdown`, `DataTable`, `Input`, `TextArea`, `Tree`, `ListView`; testing with `Pilot` / `pytest-textual-snapshot`; `textual serve` / Textual Web deploy; Rich renderables inside Textual; or streaming LLM/agent tokens into a terminal and agentic-CLI front-ends. Triggers: Textual, Textualize, TUI, terminal UI, `@work`, TCSS, `RichLog`, `query_one`, Pilot, `textual serve`. Writes current 8.x code, not stale pre-1.0 patterns. Not for: Rust TUIs (→ Ratatui sibling), Go TUIs (→ Bubble Tea sibling), plain non-interactive CLI output (Click/argparse/Typer) with no live UI, or agent-session orchestration / tmux multiplexing. Note: browser deploy via `textual serve` (the same Textual app served to a browser) IS in scope — a general React/HTML web-app request is not. | `skills/tui/textual/` |

<!-- SKILLS-INDEX:END -->

## Add a skill

1. Copy the template: `cp -r skills/_TEMPLATE skills/<category>/<your-skill>`
2. Edit `SKILL.md`. Set `name` to match the folder, write a description that says
   when to use it.
3. Add supporting files in the skill folder (`scripts/`, `reference/`, `assets/`).
4. Regenerate the index and lint: `make check`.
5. Commit. CI runs the same checks.

## Commands

| Command | What it does |
| --- | --- |
| `make lint` | Validate every `SKILL.md` |
| `make index` | Rewrite the Skills table above |
| `make check` | Lint, then verify the index is current (what CI runs) |

## Conventions

Folder names and skill `name` values are lowercase slugs. Anything under `skills/`
whose name starts with `_` (like `_TEMPLATE`) is ignored by the tooling. No secrets
in any skill: reference where they live instead.

## License

MIT. See [LICENSE](LICENSE).
