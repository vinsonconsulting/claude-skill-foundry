# Testing & debugging

## TestBackend: assert on the rendered buffer

`TestBackend` is an in-memory backend — no real terminal — so you can render a frame and
assert on the resulting cell grid. This is the bread-and-butter test for ratatui UIs:
exercise your draw code at a fixed size and compare the buffer to expected lines.

```rust
use ratatui::backend::TestBackend;
use ratatui::widgets::Paragraph;
use ratatui::Terminal;

#[test]
fn renders_greeting() {
    // TestBackend's Backend::Error is Infallible — `.unwrap()` in tests, don't `?`-into io::Result.
    let mut terminal = Terminal::new(TestBackend::new(12, 1)).unwrap();
    terminal
        .draw(|f| f.render_widget(Paragraph::new("hello"), f.area()))
        .unwrap();
    terminal.backend().assert_buffer_lines(["hello       "]); // padded to width 12
}
```

For richer expectations build a `Buffer` and assert against it (lets you assert styles,
not just text):

```rust
use ratatui::buffer::Buffer;
let mut expected = Buffer::with_lines(["hello       "]);
// expected[(0, 0)].set_style(Style::new().bold());  // assert styles too
terminal.backend().assert_buffer(&expected);
```

Guidelines:
- **Prefer buffer-level unit tests** over end-to-end driving — they're fast and
  deterministic. Test the draw function for a given state, and test `update(msg)` purely
  (no terminal needed) for state transitions.
- Pick a small fixed size so expected buffers stay readable.
- The failure diff shows which cells differ, including style mismatches.

## Snapshot tests with `insta`

For larger or evolving UIs, snapshot the rendered buffer with `insta` instead of
hand-writing expected lines — `insta` stores the approved output and shows a diff on
change (`cargo insta review` to accept):

```rust
let backend = ratatui::backend::TestBackend::new(40, 10);
let mut terminal = ratatui::Terminal::new(backend).unwrap();
terminal.draw(|f| app.draw(f)).unwrap();
insta::assert_snapshot!(terminal.backend()); // snapshots the buffer's text content
```

Snapshot the **text/layout**, not colors — color assertions are brittle across terminals
and themes; assert specific styles explicitly with `assert_buffer` when they matter.

## Graphics protocols & PTY

Image/graphics-protocol output (Sixel/Kitty via `ratatui-image`) can't be asserted with a
plain `TestBackend`. Drive the app under a real pseudo-terminal (a PTY harness) and inspect
the emitted escape sequences when you must test that path.

## Logging without wrecking the screen

`println!`/`eprintln!`/`dbg!` write straight to the terminal and **corrupt the
alternate-screen UI**. Two clean options:

- **`tui-logger`** — capture logs and show them in an in-app log widget/panel.
- **File + `tracing-subscriber`** — write structured logs to a file and `tail -f` it in
  another pane:

```rust
// at startup, before ratatui::init():
let file = std::fs::File::create("app.log")?;
tracing_subscriber::fmt().with_writer(std::sync::Mutex::new(file)).init();
tracing::info!("startup");
```

Either way, never log to stdout/stderr while the alternate screen is active.
