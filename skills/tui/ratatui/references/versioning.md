# Versioning, workspace & migration

## Pin & toolchain (verified against the installed crate)

- **ratatui 0.30.1** (current stable). Pin `ratatui = "0.30"` and let patch updates flow.
- **Rust edition 2024**, **MSRV 1.88.0** (read from ratatui 0.30.1's `rust-version`). Your
  crate needs a Rust ≥ 1.88 toolchain; edition 2024 itself needs ≥ 1.85.
- Default backend: **crossterm 0.29**. Layout solver: **`kasuari` 0.4** (not `cassowary`).

## The modular workspace (new in 0.30)

0.30 split the monolith into independently-versioned crates:

| Crate | Version | For |
| --- | --- | --- |
| `ratatui` (umbrella) | 0.30.1 | **applications** — depend on this |
| `ratatui-core` | 0.1.1 | widget/library authors; the stable core types |
| `ratatui-widgets` | 0.3.1 | the built-in widget set |
| `ratatui-crossterm` / `-termion` / `-termwiz` | 0.1.x | backend bindings |
| `ratatui-macros` | 0.7.1 | `line!`/`span!`/`text!`/`constraints!` (re-exported by the umbrella) |

**Apps use the umbrella `ratatui`** and get everything. Only depend on `ratatui-core` if
you're publishing a widget crate that wants a slimmer, more stable dependency.

## Default features

Default = `all-widgets`, `crossterm`, `layout-cache`, `macros`, `underline-color`. So the
full widget set, the crossterm backend, layout memoization, the text macros, and
underline colors are all on out of the box. Useful opt-ins:

- `serde` — (de)serialize `Style`/`Color`/etc. for themed config.
- `scrolling-regions` — flicker-free `insert_before` on supporting terminals.
- `palette` — integrate the external `palette` color crate.
- `unstable-widget-ref` — enables `WidgetRef`/`StatefulWidgetRef` (private without it).
- `crossterm_0_28` / `crossterm_0_29` — pin the crossterm bridge version.

`unstable-*` features are exempt from semver guarantees; don't ship production code on
them without accepting churn.

## tui-rs / pre-0.26 → 0.30 migration map

The library was `tui-rs`, then forked to `ratatui`; the API the model "remembers" is often
pre-0.26. Translate:

| Old (tui-rs / pre-0.26) | Current (0.30) |
| --- | --- |
| crate `tui` | crate `ratatui` |
| `enable_raw_mode()` + `execute!(EnterAlternateScreen)` + manual restore | `ratatui::init()` / `ratatui::run()` (+ restoring panic hook); `ratatui::restore()` |
| `Constraint::Proportional(n)` | `Constraint::Fill(n)` |
| `Flex::StretchLast` | `Flex::Legacy` (or just the default `Flex::Start`) |
| `SegmentSize` enum | removed — use `Flex` |
| `cassowary` solver | `kasuari` (transitive; never named in app code) |
| `Alignment` (for layout intent) | `HorizontalAlignment` (`Alignment` kept as a type alias) |
| `Layout::default().constraints(..).split(..)` only | also `Layout::vertical/horizontal(..).areas::<N>(..)` |
| `frame.size()` | `frame.area()` |
| `impl Widget for T { fn render(self, ..) }` consuming the value | `impl Widget for &T` (built-ins do this since 0.26) |
| `Terminal`/backend wired up by hand for tests | `TestBackend` + `assert_buffer`/`assert_buffer_lines` |

## Deltas found while verifying against 0.30.1

These corrected the starting research during the live compile-check — trust the installed
crate over older notes:

- **MSRV is 1.88.0**, not 1.86 — the 0.30.1 `rust-version` field says `1.88.0`.
- **The text macros ship in the umbrella** via the default `macros` feature
  (`use ratatui::macros::*`); you don't add `ratatui-macros` separately for app code.
- **`Backend::Error` is an associated type.** With the concrete `DefaultTerminal`
  (crossterm) it's `io::Error`, so `?` into `io::Result` works; with `TestBackend` it's
  `Infallible`, so tests `.unwrap()` rather than `?`. A generic `<B: Backend>` function
  can't `?`-convert into `io::Error`.
- **`Rect::centered(h, v)`** (plus `centered_horizontally` / `centered_vertically`) exist
  as first-class helpers — no need for the old hand-rolled `centered_rect`.
