# Text width & wrapping

## Display width ≠ length

A terminal cell holds one *column*. The cardinal mistake is treating `String::len()`
(bytes) or `chars().count()` (Unicode scalar values) as columns. They are all different:

- ASCII `"hi"` — 2 bytes, 2 chars, **2 columns**.
- CJK `"日本"` — 6 bytes, 2 chars, **4 columns** (each ideograph is double-width).
- `"🦀"` — 4 bytes, 1 char, **2 columns**.
- `"é"` as `e`+combining acute — 3 bytes, 2 chars, **1 column** (the mark is zero-width).
- `"🇯🇵"` (flag) — 8 bytes, 2 chars, **2 columns**.

Ratatui's widgets measure and clip by **display width** internally (via `unicode-width`),
so a `Paragraph` or `List` renders wide text correctly without help. The bugs appear when
*you* do column arithmetic: truncating a header, padding a gutter, aligning a table cell,
or computing where a manual wrap should fall. Always measure width:

```rust
use unicode_width::{UnicodeWidthStr, UnicodeWidthChar};
let cols = title.width();              // total display columns
let c_cols = '世'.width().unwrap_or(0); // per-char (None for control chars)
```

## Paragraph wrapping

```rust
use ratatui::widgets::{Paragraph, Wrap};
let p = Paragraph::new(body)
    .wrap(Wrap { trim: true })   // word-wrap by display width
    .scroll((scroll_y, 0));      // (vertical, horizontal) cell offset
```

- `Wrap { trim: true }` wraps at word boundaries and **trims leading whitespace** on
  continuation lines — good for prose.
- `Wrap { trim: false }` preserves leading whitespace, so indented/pre-formatted text
  keeps its shape. Use this for code blocks and ASCII art.
- Without `.wrap(..)`, long lines are clipped at the right edge, not wrapped.
- `.scroll((y, x))` shifts the rendered window; combine with line count to build your own
  vertical scrolling (or own the model — see `agent-ui.md`).

Wrapping respects wide characters: a double-width glyph that would overflow the last
column is pushed to the next line rather than split.

## Grapheme-safe truncation

To truncate to a column budget with an ellipsis, iterate **grapheme clusters**
(`unicode-segmentation`) so you never cut a multi-`char` glyph (emoji, flags, combining
sequences) in half, and stop by accumulated **width**:

```rust
use unicode_segmentation::UnicodeSegmentation;
use unicode_width::UnicodeWidthStr;

fn truncate_ellipsis(s: &str, max_cols: usize) -> String {
    if s.width() <= max_cols { return s.to_string(); }
    let budget = max_cols.saturating_sub(1); // reserve a column for '…'
    let mut out = String::new();
    let mut used = 0;
    for g in s.graphemes(true) {
        let w = g.width();
        if used + w > budget { break; }
        out.push_str(g);
        used += w;
    }
    out.push('…');
    out
}
```

If you only need ratatui to clip (not append an ellipsis), let the `Rect` do it — render
into a narrow area and the widget truncates by width for you.

## Alignment under wide chars

`Line::centered()` / `.right_aligned()` / `.left_aligned()` (and `Paragraph::alignment`)
compute padding from display width, so alignment is correct even with CJK/emoji. Don't
pre-pad strings with spaces to align — let the alignment API do it, or your manual padding
will be off by the wide-character delta.

```rust
use ratatui::text::Line;
let l = Line::from("ステータス: OK").right_aligned();
```
