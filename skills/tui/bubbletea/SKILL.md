---
name: bubbletea
description: >-
  Use this skill when building a terminal UI (TUI) in Go with Bubble Tea and the Charm
  stack — the Elm Architecture / MVU pattern (`tea.Model` with `Init`/`Update`/`View`),
  `Cmd`/`Msg` event flow, Lip Gloss styling and layout, Bubbles components (`viewport`,
  `list`, `table`, `textinput`, `textarea`, `spinner`, `progress`), Glamour markdown
  rendering, and teatest for testing. Especially apt for streaming tokens from an LLM/agent
  into a terminal (goroutine → `p.Send` → `Update` → `viewport`), an agentic CLI, or any
  interactive full-screen or inline terminal app in Go. Targets v2 on the
  `charm.land/*/v2` import paths (Go 1.25+); writes current-version-correct code and avoids
  v1/beta patterns. Not for: Rust TUIs (→ Ratatui sibling), Python TUIs (→ Textual
  sibling), plain non-interactive CLI output (use `fmt`/`cobra`/standalone `lipgloss`),
  web/GUI UIs, or agent session orchestration / tmux / process multiplexing.
version: 0.1.0
summary: Build current Bubble Tea v2 terminal UIs in Go on the charm.land import paths — the Elm/MVU pattern,
  Lip Gloss, Bubbles, Glamour, streaming, and teatest.
output:
  type: Code
  format: Markdown with Go code blocks
dependencies:
- charm.land/bubbletea/v2>=2.0,<3
- charm.land/lipgloss/v2
- charm.land/bubbles/v2
- go>=1.25
external_endpoints: none
permissions:
  network: false
  shell: true
  file: true
  env: false
  mcp: false
card_version: '1.0'
triggers:
  positive:
  - build a Bubble Tea TUI in Go with a viewport and a list
  - wire up the Elm Architecture Init/Update/View for my Bubble Tea model
  - stream LLM tokens from a goroutine into a Bubble Tea viewport
  - style a layout with Lip Gloss v2 and compose blocks side by side
  - my Bubble Tea Cmd/Msg isn't updating the model — debug the event flow
  - add a spinner and a progress bar from Bubbles to my Go TUI
  - render markdown in the terminal with Glamour inside Bubble Tea
  - write a teatest test for my Bubble Tea program
  - migrate my Bubble Tea v1 code to the charm.land v2 import paths
  - build an interactive full-screen Go CLI with a text input and a table
  - handle WindowSizeMsg resize and recompute my Lip Gloss layout
  - measure display width correctly for CJK/emoji in my Bubble Tea view
  negative:
  - prompt: build a Rust terminal UI
    use_instead: ratatui
  - prompt: build a Python TUI with Textual
    use_instead: textual
  - prompt: convert an image to ASCII art
    use_instead: image-to-ascii
  - prompt: render an image as terminal color blocks
    use_instead: textmode-js
  - prompt: make an ASCII-art React component
    use_instead: ascii-img-react
  - prompt: colorize a one-shot CLI message with fmt/cobra, no live UI
    use_instead: plain CLI output (no TUI skill)
  - prompt: standalone lipgloss styling with no program loop
    use_instead: plain CLI output (no TUI skill)
  - prompt: build a browser or GUI app
    use_instead: web/GUI UI (out of scope)
  - prompt: multiplex processes or orchestrate tmux
    use_instead: session orchestration (out of scope)
  - prompt: write release notes for my Go library
    use_instead: changelog (out of scope)
---

# Bubble Tea

Write current, compiling Bubble Tea **v2** code (pinned to **v2.0.x** on the
**`charm.land/*/v2`** import paths) and refuse the v1/beta patterns the model remembers
from training. The body is the load-bearing 20%: the Elm mental model and one verified
example per concept. Everything enumerable — the full Bubbles catalog, the key/mouse
taxonomy, styling, streaming, testing, migration — lives in `references/`. Open the
matching reference before writing nontrivial code in that area.

## Imports — the whole stack is on `charm.land`

Every Charm *framework* package lives on `charm.land/*/v2`. The most common v2 mistake is
importing **lipgloss or bubbles from the old `github.com/charmbracelet/…` path** while using
`charm.land` bubbletea — that pulls two incompatible trees into one build and fails to
compile. Use these paths; only the `x/*` helpers stay on `github.com`:

```go
import (
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"           // NOT github.com/charmbracelet/lipgloss
	"charm.land/bubbles/v2/viewport"   // list, table, textinput, textarea, spinner, … under bubbles/v2/<c>
	"charm.land/glamour/v2"
	"github.com/charmbracelet/x/ansi"  // width/wrap helpers — these have no charm.land alias
)
```

## Mental model — The Elm Architecture is the whole framework

Bubble Tea is **not** a widget toolkit you poke at; it is one mandatory loop. You give the
runtime a **Model** (your immutable state) and three methods, and it owns everything else:

- **Init** returns an optional first `Cmd`.
- **Update** receives a `Msg`, returns a (possibly changed) Model and an optional `Cmd`.
- **View** renders the Model to a `tea.View`.

The runtime calls `Update` for every message, then `View`, and paints the result. This is
**MVU** (Model-View-Update). The entire discipline follows from it:

- **Mutate state only inside `Update`.** Never from `View`, from a `Cmd` body, or from a
  goroutine. `Update` is the single writer; everything else races the render loop.
- **Never block in `Update`.** It runs on the render path. Do I/O — network, disk,
  subprocess, a timer — inside a `Cmd`, which the runtime runs in its own goroutine and
  whose result comes back as a `Msg`.
- **Models flow by value.** `Update` takes the Model by value, mutates the local copy, and
  returns it. Bubbles (sub-components) work the same way — you reassign what their `Update`
  returns.

## The Model interface (v2 signatures)

```go
import tea "charm.land/bubbletea/v2"

type model struct{ count int }

func (m model) Init() tea.Cmd { return nil }            // v2: Init returns ONLY a Cmd

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:                               // KeyMsg is an interface; this is the press case
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit                         // tea.Quit IS a Cmd — return it, don't call it
		case "up":
			m.count++
		case "down":
			m.count--
		}
	}
	return m, nil                                      // always return the (value) model
}

func (m model) View() tea.View {                        // v2: returns a tea.View, NOT a string
	return tea.NewView(fmt.Sprintf("count: %d", m.count))
}
```

Only **one** interface signature changed from v1: `View() string` became `View() tea.View`.
`Init() Cmd` and `Update(Msg) (Model, Cmd)` are unchanged — do not "modernize" them.

## Cmd & Msg

A **`Cmd` is `func() tea.Msg`** — a deferred IO/effect the runtime runs in its own
goroutine; its returned `Msg` is fed back into `Update`. A **`Msg` is any value** (the type
is the empty interface), so your own types are messages:

```go
type tickMsg time.Time

func tick() tea.Cmd {
	return tea.Tick(time.Second, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// In Update, combine effects:
return m, tea.Batch(tick(), fetchData())   // Batch: concurrent; Sequence: one after another
```

`Batch`, `Sequence`, `Tick`, `Every`, and `Quit` are the everyday command constructors.
The runtime also sends you **built-in messages** you switch on and route down yourself —
most importantly `tea.WindowSizeMsg` (one at startup and on every resize), plus key and
mouse messages:

```go
case tea.WindowSizeMsg:
	m.width, m.height = msg.Width, msg.Height
	m.vp.SetWidth(msg.Width)              // forward sizes into child components
	m.vp.SetHeight(msg.Height - 2)        // leave room for header + footer
```

Full key/mouse taxonomy (the `Key` struct, `Mod.Contains`, mouse message types) is in
`references/architecture.md`.

## Program & lifecycle

```go
func main() {
	p := tea.NewProgram(initialModel())   // NO WithAltScreen()/WithMouseCellMotion() — gone in v2
	if _, err := p.Run(); err != nil {     // Run returns (final Model, error)
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
```

In **v2, alt-screen and mouse are `tea.View` fields**, not `NewProgram` options — you set
them on the view you return, so they are part of your render state:

```go
func (m model) View() tea.View {
	v := tea.NewView(body)
	v.AltScreen = true                     // full-window mode
	v.MouseMode = tea.MouseModeCellMotion  // also: MouseModeNone, MouseModeAllMotion
	return v
}
```

The runtime owns raw mode and the cursor (the "Cursed Renderer", backed by `ultraviolet`).
**It catches panics by default and restores the terminal**, returning `ErrProgramPanic`
from `Run()` (`WithoutCatchPanics` opts out); `ErrInterrupted` and `ErrProgramKilled` are
the other sentinels. Do **not** hand-roll raw mode or teardown. For logs, never write to
stdout while the UI is up — use `tea.LogToFile("debug.log", "")`. Details and the remaining
`ProgramOption`s are in `references/architecture.md`.

## Layout with Lip Gloss

Lip Gloss has **no constraint solver** — layout is **styled-string composition**. You size
blocks (from `WindowSizeMsg`), style them, and glue them with `JoinHorizontal` /
`JoinVertical` / `Place`. Measure with **`lipgloss.Width` / `lipgloss.Size`, never
`len()`** (bytes ≠ display columns):

```go
// 30-cell sidebar + flexible main, with header and footer
sidebar := lipgloss.NewStyle().Width(30).Render(nav)
main := lipgloss.NewStyle().Width(m.width - 30).Render(content)  // total - sidebar
body := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, main)
ui := lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
_ = lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, popup) // centering
```

Styles, colors (and v2's "pure" color model + `colorprofile` downsampling), borders, and
absolute-positioned overlays via `lipgloss.NewCanvas`/`NewLayer` are in
`references/styling-and-layout.md`.

## Components (Bubbles)

**Every Bubble is itself a `Model`** (`Init`/`Update`/`View`). Nest its model in your
struct, route messages (including `WindowSizeMsg`) into its `Update`, **reassign** the
returned model, and bubble its `Cmd` up:

```go
type model struct{ list list.Model }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)   // route down, reassign, bubble the Cmd up
	return m, cmd
}

func (m model) View() tea.View { return tea.NewView(m.list.View()) } // child returns a string
```

The catalog (`viewport`, `list`, `table`, `textinput`, `textarea`, `spinner`, `progress`,
`help`, `key`, `paginator`, `filepicker`, `stopwatch`, `timer`, `cursor`, all under
`charm.land/bubbles/v2/<c>`), how to author your own Bubble, and **the Crush escape hatch**
— at scale, one top-level `tea.Model` whose sub-components are plain structs with
imperative methods returning `tea.Cmd` instead of a full `Update` fan-out — are in
`references/components.md`.

## Text width & wrapping — the streaming-chat footgun

One `char` (or byte) is **not** one column. CJK ideographs and many emoji are **two**
columns; combining marks are zero; ZWJ/flag emoji are several runes but a couple of
columns. Measure display width, and slice/wrap with width-aware helpers:

```go
import "github.com/charmbracelet/x/ansi"

w := lipgloss.Width(s)                 // display columns; == ansi.StringWidth(s)
clipped := ansi.Truncate(s, 20, "…")   // ANSI-safe, width-aware truncate (not byte slicing)
wrapped := ansi.Wrap(longLine, 40, "") // hard wrap to 40 columns without breaking escapes
```

Footgun: `ansi.StringWidth` misreads if you feed it rune-by-rune — measure whole strings.
Markdown via Glamour buffers the **entire** input and re-renders, and partial/unclosed
markdown flickers while streaming. Full rules and a grapheme-safe approach:
`references/text-and-unicode.md`.

## Streaming LLM output

The canonical agent-UI loop: a producer goroutine pushes deltas through **`p.Send`**, the
*only* goroutine-safe channel into the UI; `Update` appends and re-renders into a
`viewport`; auto-follow is gated on `AtBottom()` so it pins when the user scrolls up.

```go
type deltaMsg string

type model struct {
	vp  viewport.Model
	buf string
}

// v2 viewport is built with functional options — NOT positional viewport.New(w, h):
func newModel() model {
	return model{vp: viewport.New(viewport.WithWidth(80), viewport.WithHeight(24))}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.vp.SetWidth(msg.Width)
		m.vp.SetHeight(msg.Height - 1)
	case deltaMsg:
		atBottom := m.vp.AtBottom()        // check BEFORE mutating content
		m.buf += string(msg)
		m.vp.SetContent(m.buf)             // or glamour.Render(m.buf) for markdown
		if atBottom {
			m.vp.GotoBottom()              // follow only if we were already pinned
		}
	}
	return m, nil
}

// Capture *tea.Program once, then stream from a goroutine:
func stream(p *tea.Program, tokens <-chan string) {
	go func() {
		for t := range tokens {
			p.Send(deltaMsg(t))            // NEVER touch m or call vp.Update from here
		}
	}()
}
```

The `viewport` Bubble owns scrollback — don't hand-roll a ring buffer. `tea.Listen` is a
**proposal, not real**; `Cmd` + `p.Send` is the whole concurrency story. The deep dive
(width-keyed render cache, the Crush pubsub→`program.Send` bridge, follow/freeze) is in
`references/agent-ui.md`; this skill covers the **in-process** UI only — multi-session
orchestration / tmux is a separate concern.

## Stale patterns to reject (v1 / github.com beta)

If you catch yourself writing any of these, stop — they won't compile on v2:

| Reject | Use instead |
| --- | --- |
| `github.com/charmbracelet/bubbletea` (or its `/v2` **beta** path) | `charm.land/bubbletea/v2` — keep the **whole** stack on `charm.land/*/v2` |
| `github.com/charmbracelet/lipgloss` or `…/bubbles` (v1) | `charm.land/lipgloss/v2`, `charm.land/bubbles/v2/<c>` — never mix `github.com` + `charm.land` |
| `viewport.New(w, h)` (positional, v1) | `viewport.New(viewport.WithWidth(w), viewport.WithHeight(h))` |
| `View() string` | `View() tea.View` (`tea.NewView`; child components still return `string`) |
| `tea.WithAltScreen()` / `WithMouseCellMotion()` as `NewProgram` options | set `v.AltScreen` / `v.MouseMode` on the returned `tea.View` |
| `KeyMsg` struct with `.Type` / `.Runes` | `KeyPressMsg`/`KeyReleaseMsg`; match `msg.String()` or `msg.Key().Code` |
| matching space as `" "` | space is `"space"` |
| `MouseMsg` struct with `.Action` / `.Button` | `MouseClickMsg` / `MouseWheelMsg` / `MouseMotionMsg` (`MouseMsg` is an interface) |
| mutating the Model from a goroutine, `View`, or a `Cmd` body | send a `Msg` via `p.Send`; mutate only in `Update` |
| calling `model.Update` / `component.Update` from outside the loop | let the runtime drive `Update`; from outside, only `p.Send` |
| blocking I/O in `Update` | do it in a `Cmd` (runs in its own goroutine) |
| `len(s)` for display width | `lipgloss.Width(s)` / `ansi.StringWidth(s)` |

Note `Init() tea.Cmd` is **correct** in v2 (unchanged from v1) — do not "fix" it.
Verified against bubbletea v2.0.7 / lipgloss v2.0.4 / bubbles v2.1.0.

## Reference map

- `references/architecture.md` — MVU depth, the full v2 key/mouse taxonomy, the Cursed Renderer, lifecycle & `ProgramOption`s, logging.
- `references/styling-and-layout.md` — Lip Gloss styles/joins/`Place`/color, v2 color purity + `colorprofile`, canvas/layers.
- `references/components.md` — the Bubbles catalog, authoring a custom Bubble, the Crush sole-model scaling pattern.
- `references/text-and-unicode.md` — `x/ansi` width/wrap/truncate, graphemes, emoji/ZWJ footguns, Glamour streaming flicker.
- `references/agent-ui.md` — streaming deep dive (in-process only), the Crush pubsub→`Send` bridge, width-keyed render cache.
- `references/ecosystem.md` — the Charm constellation (huh, wish, glamour, log, …) and pinned versions.
- `references/testing.md` — pure `Update` state-machine tests and `teatest/v2` (with its experimental caveats).
- `references/versioning.md` — the v1↔v2 migration map, module paths, the Go floor, and the verified Charm-stack table.
