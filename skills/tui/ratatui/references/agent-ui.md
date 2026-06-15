# Streaming LLM output in Ratatui

**Scope:** this file is about the *Ratatui* side of a streaming chat/agent TUI — owning
scrollback, following vs. freezing, the buffer ceiling, and feeding the model from an
async stream. **Out of scope:** agent *orchestration* — tmux multiplexing, multi-session
management, JSONL transcript parsing, actor/process supervision. That belongs to a
separate orchestration skill; do not build it here.

## Own your scrollback — do not render off-screen

The instinct to render a giant `Paragraph` of the entire transcript and scroll it fails
hard: a `Buffer`'s dimensions are `u16`, so any single rendered region caps at **65,535
cells per side**. A long conversation overflows that, and rendering thousands of
off-screen lines every frame is wasteful regardless. Ratatui maintainers' guidance: don't
render what isn't visible. Instead keep the transcript in **your own model** and render
only the visible slice.

```rust
use std::collections::VecDeque;
use ratatui::layout::Rect;
use ratatui::text::Line;
use ratatui::widgets::{Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState};
use ratatui::Frame;

pub struct Scrollback {
    lines: VecDeque<Line<'static>>, // the model — NOT a Buffer
    offset: usize,                  // index of the top visible line
    follow: bool,                   // true = pinned to bottom (auto-scroll)
}

impl Scrollback {
    pub fn push(&mut self, line: Line<'static>) {
        self.lines.push_back(line);
        if self.lines.len() > 100_000 {      // optional cap to bound memory
            self.lines.pop_front();
        }
        // when following, the render step recomputes offset to the new bottom
    }

    /// User scrolled up: freeze (stop following). Scrolled to bottom: resume following.
    pub fn scroll_up(&mut self, n: usize) {
        self.offset = self.offset.saturating_sub(n);
        self.follow = false;
    }
    pub fn scroll_down(&mut self, n: usize, viewport_h: usize) {
        let max = self.lines.len().saturating_sub(viewport_h);
        self.offset = (self.offset + n).min(max);
        self.follow = self.offset >= max; // re-pin if we reached the bottom
    }

    pub fn draw(&mut self, frame: &mut Frame, area: Rect) {
        let h = area.height as usize;
        let max_off = self.lines.len().saturating_sub(h);
        if self.follow {
            self.offset = max_off; // auto-follow: always show the tail
        }
        let visible: Vec<Line> = self
            .lines
            .iter()
            .skip(self.offset)
            .take(h)
            .cloned()
            .collect();
        frame.render_widget(Paragraph::new(visible), area);

        // scrollbar reflects position within the whole transcript
        let mut sb = ScrollbarState::new(max_off).position(self.offset);
        frame.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight),
            area,
            &mut sb,
        );
    }
}
```

Key behaviors this encodes:
- **Auto-follow** while pinned to the bottom; **freeze** the moment the user scrolls up.
- Render only `area.height` lines, so cost is independent of transcript length.
- `ScrollbarState` is driven by `(offset, content_length)`, where content length is the
  scrollable range (`lines.len() - viewport_height`).
- For deltas that extend the last line (token streaming), mutate the back `Line` in place
  instead of pushing a new one; re-wrap only if your layout needs it.

## Feeding it from a stream (tokio)

Use tokio only when you actually block on I/O (network, subprocess, DB). Multiplex input,
the token stream, and a render tick with `select!`, and **redraw on the tick, not per
delta**, so a fast stream can't pin the CPU repainting.

```rust
use std::time::Duration;
use tokio::sync::mpsc;

enum Action { Delta(String), Input(/* key */), Quit }

async fn run(mut terminal: ratatui::DefaultTerminal, mut rx: mpsc::UnboundedReceiver<Action>)
    -> color_eyre::Result<()>
{
    let mut model = Scrollback::default();
    let mut render_tick = tokio::time::interval(Duration::from_millis(33)); // ~30 fps
    let mut dirty = true;
    loop {
        tokio::select! {
            _ = render_tick.tick() => {
                if dirty {
                    terminal.draw(|f| model.draw(f, f.area()))?;
                    dirty = false;
                }
            }
            maybe = rx.recv() => match maybe {
                Some(Action::Delta(s)) => { model.append_token(&s); dirty = true; }
                Some(Action::Input(_)) => { /* update scroll/follow */ dirty = true; }
                Some(Action::Quit) | None => break,
            }
        }
    }
    Ok(())
}
```

Bridge crossterm input into the same channel with `crossterm`'s `EventStream` (enable its
`event-stream` feature) in a spawned task, or poll input on a short timeout in a blocking
task and forward `Action`s. A synchronous `event::poll` loop is perfectly fine for a chat
UI that only streams text — reach for tokio when concurrency is real.

## Alternative: inline scrollback with `insert_before`

If you want the transcript to live in the terminal's *native* scrollback (so the user
scrolls with their normal terminal/mouse) and only a small live region is managed by
ratatui, use `Terminal::insert_before` (pair with the `scrolling-regions` feature for
flicker-free behavior on supporting terminals):

```rust
// terminal: &mut DefaultTerminal — crossterm's Backend::Error is io::Error, so `?` works
terminal.insert_before(1, |buf| {
    use ratatui::widgets::{Paragraph, Widget};
    Paragraph::new(finished_line).render(buf.area, buf);
})?;
```

This emits completed lines above the live viewport and lets the host terminal own history
— a good fit when you don't need in-app scroll/search. The own-the-`VecDeque` model above
is the choice when you need search, selection, or custom scroll behavior.
