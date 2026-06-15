# Ecosystem & backends

Version compatibility below was checked against crates.io at the time of writing (ratatui
0.30.1 era). **Always re-check a crate's `ratatui` requirement before adding it** — the
ecosystem tracks ratatui releases at different speeds, and a crate pinned to 0.29 will
fail to compile against 0.30 in the same tree.

## Companion crates

| Crate | Latest | Targets | What it is |
| --- | --- | --- | --- |
| `tui-realm` (`tuirealm`) | 4.1.0 | ratatui ^0.30 | Elm/React-style component framework: component tree, focus, subscriptions. Reach for it instead of hand-rolling app architecture. |
| `tachyonfx` | 0.25.0 | ratatui ^0.30 | Shader-like cell effects/animations (fades, transitions) over a buffer. |
| `ratzilla` | 0.3.1 | ratatui ^0.30.1 | Run ratatui UIs in the **browser** via WebAssembly (canvas/DOM backend). |
| `tui-textarea` | 0.7.0 | ratatui ^0.29 | Multi-line text editor widget. **Note: still on 0.29 at time of writing** — verify before mixing with 0.30. |
| `ratatui-image` | 11.0.4 | ratatui ^0.30.1 | Render images in-terminal (Sixel, Kitty, iTerm2, halfblocks). |
| `rat-salsa` | 4.0.3 | ratatui-core ^0.1 / ratatui-widgets ^0.3 | Larger application framework + rich widget set, built directly on the modular crates. |
| `tui-popup` | 0.7.6 | ratatui ^0.30 | Drop-in popup/dialog widget (saves the Clear + centering dance). |
| `bevy_ratatui` | 0.11.1 | ratatui ^0.30 | Drive a ratatui UI from the Bevy ECS/event loop. |
| `tui-logger` | 0.18.2 | ratatui ^0.30 | In-app log widget + capture, so logging doesn't corrupt the alt-screen (see `testing.md`). |

`ratatui-macros` (the `line!`/`span!`/`text!`/`constraints!` macros) ships **inside** the
umbrella via the default `macros` feature — you usually don't add it separately.

## Backends

The umbrella `ratatui` defaults to the **crossterm** backend (currently `crossterm 0.29`),
which is cross-platform (Linux/macOS/Windows) and the right default. Alternatives:

- **termion** (`ratatui-termion`) — Unix-only, no Windows; lighter, no extra C deps.
- **termwiz** (`ratatui-termwiz`) — the wezterm stack; useful if you're already in it.

Select a non-default backend by disabling default features and enabling the backend
feature, then constructing the `Terminal` yourself with that backend.

### crossterm version coupling

ratatui re-exports its crossterm at `ratatui::crossterm` — **import key/event types from
there**, not from a separately-added `crossterm`, or you can end up with two incompatible
crossterm versions in the tree (type mismatches on `KeyEvent` etc.). If you must depend on
crossterm directly, match the version ratatui uses, or use ratatui's `crossterm_0_28` /
`crossterm_0_29` features to pin the bridge.

### The Windows duplicate-key gotcha

On Windows, crossterm reports both key **press** and **release** (and repeats) as
`Event::Key`. If you act on every key event, every keypress fires twice. Filter to
presses:

```rust
use ratatui::crossterm::event::{Event, KeyEventKind};
if let Event::Key(key) = event::read()? {
    if key.kind != KeyEventKind::Press { return Ok(()); } // ignore Release/Repeat
    // handle key.code
}
```

## Exemplars worth reading

Version-correct, in the ratatui repo: `examples/` and `ratatui-widgets/examples/`.
Real apps: **Oatmeal** and **tenere** (in-process streaming LLM chat — closest to the
`agent-ui.md` patterns), **gitui**, **atuin**, **television**, **yazi**, **gobang**.
(Note: tmux-style multi-session orchestrators are a different concern — see the scope note
in `agent-ui.md`.)
