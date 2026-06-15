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

### dev

| Skill | Description | Path |
| --- | --- | --- |
| `env-doctor` | Diagnose a broken local development environment by checking language runtimes, package managers, environment variables, and common path or version mismatches. Use when a project will not build, run, or install dependencies and the cause is unclear. | `skills/dev/env-doctor/` |

### tui

| Skill | Description | Path |
| --- | --- | --- |
| `ratatui` | Use this skill for any task involving a Rust terminal/text user interface (TUI) built with Ratatui (or crossterm) — creating one, or debugging, fixing, testing, or extending an existing one. Covers: scaffolding the initial `main`/render loop and terminal setup; fixing teardown so a panic or crash doesn't leave the terminal in raw mode / broken; laying out panels, sidebars, status bars, dashboards, and popups with Layout/Constraint; wiring widgets like List, Table, Gauge, Chart, Scrollbar (including selection/scroll state that won't move); styling, text wrapping, and Unicode width issues; streaming LLM/async output into a terminal; and unit-testing rendered output without a real terminal. Triggers on "rust + terminal app/UI/dashboard", ratatui, crossterm. Writes current Ratatui 0.30+ code, not stale tui-rs patterns. Not for: Go TUIs (Bubble Tea), Python TUIs (Textual), non-interactive CLI output or progress bars, web/browser UIs, image-to-ASCII art (ascii/textmode), or tmux/agent-session orchestration. | `skills/tui/ratatui/` |

### writing

| Skill | Description | Path |
| --- | --- | --- |
| `plain-language-edit` | Rewrite dense, jargon-heavy, or bureaucratic text into plain language without losing meaning. Use when a user asks to simplify, de-jargon, or make writing clearer and more direct, or when prose reads like corporate boilerplate. | `skills/writing/plain-language-edit/` |

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
