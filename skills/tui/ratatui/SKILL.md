---
name: ratatui
description: >-
  Use this skill for any task involving a Rust terminal/text user interface (TUI) built
  with Ratatui (or crossterm) — creating one, or debugging, fixing, testing, or extending
  an existing one. Covers: scaffolding the initial `main`/render loop and terminal setup;
  fixing teardown so a panic or crash doesn't leave the terminal in raw mode / broken;
  laying out panels, sidebars, status bars, dashboards, and popups with Layout/Constraint;
  wiring widgets like List, Table, Gauge, Chart, Scrollbar (including selection/scroll state
  that won't move); styling, text wrapping, and Unicode width issues; streaming LLM/async
  output into a terminal; and unit-testing rendered output without a real terminal. Triggers
  on "rust + terminal app/UI/dashboard", ratatui, crossterm. Writes current Ratatui 0.30+
  code, not stale tui-rs patterns. Not for: Go TUIs (Bubble Tea), Python TUIs (Textual),
  non-interactive CLI output or progress bars, web/browser UIs, image-to-ASCII art
  (ascii/textmode), or tmux/agent-session orchestration.
version: 0.1.0
summary: Write current, compiling Ratatui 0.30+ terminal UIs in Rust — render loop and teardown, Layout/Constraint,
  widgets, styling, Unicode width, streaming, and headless render tests.
output:
  type: Code
  format: Markdown with Rust code blocks
dependencies:
- ratatui>=0.30,<0.31
- crossterm
- rust>=1.85 (2024 edition)
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
  - build a Rust dashboard TUI with ratatui that has a sidebar and a live-updating chart
  - my ratatui app leaves the terminal in raw mode after a panic — fix the teardown
  - lay out three panels with Layout and Constraint in ratatui
  - render a scrollable List with persistent selection state in ratatui
  - stream tokens from an async task into a ratatui terminal without flicker
  - my ratatui table's Unicode/CJK column widths are misaligned
  - write a headless render test for my ratatui widget with TestBackend
  - set up the crossterm event loop and terminal init for a new ratatui app
  - add a popup/modal overlay on top of my ratatui layout
  - migrate my old tui-rs code to current ratatui 0.30
  - draw a Gauge and a Sparkline that update each frame in ratatui
  - why does my ratatui Scrollbar not move when I scroll the list
  negative:
  - prompt: build a terminal UI in Go with Bubble Tea
    use_instead: bubbletea
  - prompt: build a Python TUI with Textual
    use_instead: textual
  - prompt: convert this image to ASCII art
    use_instead: image-to-ascii
  - prompt: render an image as colored terminal blocks
    use_instead: textmode-js
  - prompt: make an ASCII-art React component
    use_instead: ascii-img-react
  - prompt: add a progress bar to a non-interactive CLI script
    use_instead: plain CLI output (no TUI skill)
  - prompt: just print a colored table to stdout, no interactivity
    use_instead: plain CLI output (no TUI skill)
  - prompt: build a web dashboard in React
    use_instead: web UI (out of scope)
  - prompt: orchestrate tmux panes for my agent session
    use_instead: session orchestration (out of scope)
  - prompt: write a CLAUDE.md for my Rust project
    use_instead: project docs (out of scope)
---

# Ratatui

Write current, compiling Ratatui code (pinned to **0.30.x**, Rust 2024) and refuse the
stale tui-rs patterns the model remembers from training. The body is the load-bearing
20%: one mental model and one verified example per concept. Everything enumerable —
the full widget catalog, every constraint, the streaming model, testing, migration —
lives in `references/`. Open the matching reference before writing nontrivial code in
that area.

## Mental model

Ratatui is **immediate mode**: there are no retained widget objects. Every frame you
build the whole UI from your own application state and throw it away. A render loop
runs `terminal.draw(|frame| …)`; inside, you slice the area into rectangles and draw
widgets into them. Ratatui keeps two `Buffer`s and **diffs** them, writing only the
changed cells to the terminal — so redrawing the entire screen every frame is cheap and
correct. You own the loop: read an event, update state, draw, repeat.

Four nouns carry everything:

- **Terminal** — owns the backend (crossterm by default) and the double buffers; gives you a `Frame`.
- **Frame** — one frame's drawing surface; `frame.area()` is the full `Rect`, `frame.render_widget(w, rect)` draws.
- **Buffer** — the grid of styled cells widgets write into. Dimensions are `u16` (max 65,535 per side).
- **Rect** — an `x/y/width/height` region in `u16`. Layout is just splitting one `Rect` into more `Rect`s.

## Lifecycle: never hand-roll the terminal

Ratatui sets up raw mode, the alternate screen, and a panic hook for you. **Do not call
`enable_raw_mode`, `EnterAlternateScreen`, or any manual teardown** — if you do, a panic
or early return leaves the user's terminal wrecked.

```rust
fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;            // BEFORE init(): ratatui's panic hook must be outermost,
    let terminal = ratatui::init();    // so it restores the screen before color-eyre prints.
    let result = App::default().run(terminal);
    ratatui::restore();                // always runs; restore BEFORE surfacing the error
    result
}
```

`ratatui::run(|terminal| { … })` is the same thing inlined: it is literally
`init()` → your closure → `restore()`, returning whatever the closure returns. Use
`init()`/`restore()` when the terminal must outlive one closure (e.g. stored in your
`App`); use `run` for throwaway examples. Drop to `Terminal::new(CrosstermBackend::new(…))`
only when you need a non-default backend or writer. `init()` enables raw mode + alternate
screen and installs a restoring panic hook; `restore()` reverses it and never panics.

## App loop: state + message + update + draw

Model the app as state plus a message/action enum; events become messages, messages
mutate state, then you redraw. This keeps event handling testable and draw code pure.

```rust
#[derive(Default)]
struct App { count: i64, running: bool }

enum Msg { Inc, Dec, Quit }

impl App {
    fn run(mut self, mut terminal: ratatui::DefaultTerminal) -> color_eyre::Result<()> {
        self.running = true;
        while self.running {
            terminal.draw(|frame| self.draw(frame))?;
            if let Some(msg) = self.next_event()? { self.update(msg); }
        }
        Ok(())
    }

    fn update(&mut self, msg: Msg) {
        match msg {
            Msg::Inc => self.count += 1,
            Msg::Dec => self.count -= 1,
            Msg::Quit => self.running = false,
        }
    }

    fn draw(&self, frame: &mut ratatui::Frame) {
        frame.render_widget(format!("count: {}", self.count), frame.area());
    }

    fn next_event(&self) -> color_eyre::Result<Option<Msg>> {
        use ratatui::crossterm::event::{self, Event, KeyCode, KeyEventKind};
        if !event::poll(std::time::Duration::from_millis(100))? { return Ok(None); }
        let Event::Key(key) = event::read()? else { return Ok(None) };
        if key.kind != KeyEventKind::Press { return Ok(None); } // ignore Windows key-repeat/release
        Ok(match key.code {
            KeyCode::Char('q') => Some(Msg::Quit),
            KeyCode::Up        => Some(Msg::Inc),
            KeyCode::Down      => Some(Msg::Dec),
            _ => None,
        })
    }
}
```

If you want this architecture off the shelf (component tree, subscriptions, focus),
reach for **`tui-realm`** rather than reinventing it — see `references/ecosystem.md`.

## Layout

Split a `Rect` with `Layout::vertical`/`Layout::horizontal` plus a list of `Constraint`s,
then destructure with `.areas::<N>()` (compile-time count) or `.split(area)` (dynamic,
returns `Rc<[Rect]>`). The six constraints are **`Length`, `Percentage`, `Ratio`, `Min`,
`Max`, `Fill`** — note **`Fill`**, not the removed `Proportional`. When constraints
compete, priority is **Min > Max > Length > Percentage > Ratio > Fill**. The default
`Flex` is **`Flex::Start`** (no stretching); change it with `.flex(Flex::Center | SpaceBetween | …)`.

```rust
use ratatui::layout::{Constraint, Layout};
// 3-line header, filling body, 1-line status bar
let [header, body, status] = Layout::vertical([
    Constraint::Length(3), Constraint::Fill(1), Constraint::Length(1),
]).areas(frame.area());
// body: fixed 30-cell sidebar + filling main
let [sidebar, main] =
    Layout::horizontal([Constraint::Length(30), Constraint::Fill(1)]).areas(body);
```

**Popups:** compute a centered region, then **always `render_widget(Clear, area)` first**
so the popup isn't transparent over the content beneath it:

```rust
use ratatui::layout::Constraint;
use ratatui::widgets::{Block, Clear};
let area = frame.area().centered(Constraint::Percentage(60), Constraint::Length(10));
frame.render_widget(Clear, area);
frame.render_widget(Block::bordered().title("Confirm"), area);
```

Constraint nuances, `Flex` modes, `spacing`/`margin`/`inner`, nested layouts, and the
layout cache are in `references/layout.md`.

## Widgets

Stateless widgets (`Block`, `Paragraph`, `Gauge`, …) are constructed and rendered each
frame. **Stateful** widgets (`List`, `Table`, `Scrollbar`) keep their selection/scroll in
a `*State` you own in your `App` and pass via `render_stateful_widget` — never store it in
the widget, which is rebuilt every frame.

```rust
use ratatui::widgets::{List, ListState};
// in App: list: ListState  (call list.select_next() / select_previous() on j/k)
let items = List::new(["alpha", "beta", "gamma"]).highlight_symbol("> ");
frame.render_stateful_widget(items, area, &mut self.list);
```

**Custom widgets:** implement `Widget` for a **reference** so the caller keeps ownership
(every built-in does this since 0.26). Use `impl Widget for &mut T` if you must mutate
during render; `StatefulWidget` when the widget needs external state.

```rust
use ratatui::{buffer::Buffer, layout::Rect, text::Line, widgets::Widget};
struct Bar { pct: u16 }
impl Widget for &Bar {
    fn render(self, area: Rect, buf: &mut Buffer) {
        Line::from(format!("{}%", self.pct)).render(area, buf); // write via Line/Span/set_*, not escapes
    }
}
// frame.render_widget(&bar, area);
```

`WidgetRef`/`StatefulWidgetRef` exist but are **unstable** — gated behind the
`unstable-widget-ref` feature (the trait is private without it). Don't reach for them by
default. Full catalog and per-widget notes: `references/widgets.md`.

## Styling

`Style` + `Modifier` carry color and attributes, but reach for the `Stylize` trait's
shorthands. Text nests **Span ⊂ Line ⊂ Text**, and styles cascade down (a `Line` style is
a default its `Span`s patch).

```rust
use ratatui::style::{Stylize, palette::tailwind};
use ratatui::text::{Line, Span};
let line = Line::from(vec![
    Span::raw("status: "),
    "online".fg(tailwind::GREEN.c400).bold(),
]);
let _ = "error".red().on_black().bold();
```

The `line!`/`span!`/`text!` macros ship in the umbrella via the default `macros` feature
(`use ratatui::macros::*`). More in `references/widgets.md`.

## Text width & wrapping — the streaming-chat footgun

The single most common bug in terminal chat UIs: assuming one `char` (or one byte) is one
column. **It isn't.** CJK ideographs and many emoji are **two** columns wide; combining
marks are zero; a flag emoji is several `char`s but two columns. Ratatui measures and
clips by **display width** (via `unicode-width`), so trust its widgets — but the moment
*you* do column math (truncating a title, aligning a gutter, computing a wrap point),
measure width, never length:

```rust
use unicode_width::UnicodeWidthStr;
let cols = title.width();          // display columns — NOT title.len() (bytes) or .chars().count()
```

`Paragraph::new(text).wrap(Wrap { trim: true })` wraps at word boundaries by display
width and trims leading whitespace on wrapped lines (`trim: false` preserves indentation);
`.scroll((y, x))` offsets the view. For grapheme-correct truncation with an ellipsis, work
in graphemes (`unicode-segmentation`) and stop by accumulated width. `references/text-and-unicode.md`
has the wrapping rules, alignment under wide chars, and a width-aware truncate helper.

## Async render loop

A synchronous `event::poll(timeout)` loop (shown above) is fine and lighter — use it
unless you block on network/DB I/O. When you do, move to tokio: multiplex input, your
data stream, and a **render tick** with `select!`, and **redraw on the tick, not per
message**, so a fast stream can't pin the CPU repainting.

```rust
use tokio::sync::mpsc;
enum Action { Delta(String), Render, Quit }
// loop { tokio::select! {
//     _ = render_tick.tick()   => terminal.draw(|f| app.draw(f))?,   // ~30–60 fps cap
//     Some(a) = actions.recv() => app.apply(a),                      // stream deltas, input
// } }
```

Streaming LLM output specifically (own-your-scrollback `VecDeque<Line>`, auto-follow vs.
freeze-on-scroll, `ScrollbarState`, the u16 buffer ceiling, `insert_before`): see
`references/agent-ui.md`.

## Stale patterns to reject

If you catch yourself writing any of these, stop — they are tui-rs / pre-0.26 and won't
compile on 0.30:

| Reject | Use instead |
| --- | --- |
| `enable_raw_mode()` / `EnterAlternateScreen` / manual teardown | `ratatui::init()` / `run()` (handles it + panic hook) |
| `Constraint::Proportional(n)` | `Constraint::Fill(n)` |
| `Flex::StretchLast`, `SegmentSize` | `Flex` (default `Start`); the type is gone |
| the `cassowary` crate | first-party `kasuari` (transitive; you don't name it) |
| bare `Alignment` for layout intent | `HorizontalAlignment` (`Alignment` is a kept alias) |
| `Widget::render(self, …)` consuming a value you still need | `impl Widget for &T`; `render_widget(&w, area)` |
| wrap/truncation by `.len()` / `.chars().count()` | display width via `unicode-width` |

Confirmed against ratatui 0.30.1: `Proportional`, `StretchLast`, and `SegmentSize` do not
exist; `cassowary` is absent (`kasuari` is the solver).

## Reference map

- `references/layout.md` — constraints in depth, priority, `Flex`, spacing/margin/inner, `.split` vs `.areas`, centering, layout cache.
- `references/widgets.md` — full built-in catalog, stateful patterns, custom-widget traits, `Stylize`/macros, the unstable `WidgetRef` feature.
- `references/text-and-unicode.md` — display width vs char/byte, `Wrap` semantics, grapheme-safe truncation, alignment under wide chars.
- `references/agent-ui.md` — streaming LLM scrollback (Ratatui-only); orchestration is out of scope.
- `references/ecosystem.md` — tui-realm, ratzilla, tachyonfx, backends, and current ratatui-version compatibility per crate.
- `references/testing.md` — `TestBackend` buffer assertions, snapshot tests, logging without corrupting the screen.
- `references/versioning.md` — the 0.30 modular workspace, MSRV/edition, feature flags, and the tui-rs → 0.30 migration map.
