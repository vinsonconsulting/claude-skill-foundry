# Widgets

## Built-in catalog (module `ratatui::widgets`)

| Widget | State | Notes |
| --- | --- | --- |
| `Block` | — | borders, titles, padding; container for other widgets via `block.inner(area)` |
| `Paragraph` | — | wrapped/aligned text; `.wrap(Wrap{..})`, `.scroll((y,x))`, `.block(..)` |
| `List` | `ListState` | selectable rows; `highlight_symbol`, `highlight_style`, `HighlightSpacing` |
| `Table` | `TableState` | columns via `Constraint`s; `header`, `row_highlight_style` |
| `Tabs` | — | `.select(i)`; render a tab bar |
| `Gauge` | — | `.percent(u16)` or `.ratio(f64)`; progress bar with label |
| `LineGauge` | — | single-line gauge; `.ratio(f64)` |
| `Sparkline` | — | `.data(&[u64])`; compact bar history |
| `Chart` | — | `Dataset` + `Axis`; scatter/line plots |
| `BarChart` | — | `.data(&[(&str,u64)])`; labeled bars |
| `Canvas` | — | `.paint(\|ctx\| ..)`; freeform drawing with shapes (Line, Rectangle, Map, Points) |
| `Calendar` | — | needs the `widget-calendar` feature (in default `all-widgets`) |
| `Clear` | — | erases a region; render before popups |

`&str`, `String`, `Span`, `Line`, and `Text` all implement `Widget`, so
`frame.render_widget("hi", area)` and `frame.render_widget(some_line, area)` work directly.

## Block: the container

```rust
use ratatui::widgets::{Block, BorderType, Borders, Padding};
let b = Block::bordered()                 // == .borders(Borders::ALL)
    .border_type(BorderType::Rounded)     // Plain | Rounded | Double | Thick
    .padding(Padding::uniform(1))
    .title("top")                         // top-left by default
    .title_bottom("help: q quit");
// render the block, then draw inside b.inner(area)
```

## Stateful widgets: own the state

Selection and scroll live in a `*State` you keep in your `App`, not in the widget (which
is rebuilt every frame). Pass it via `render_stateful_widget`.

```rust
use ratatui::widgets::{List, ListState};
// App { list: ListState }  — drive it from key handlers:
app.list.select_next();        // also select_previous(), select_first(), select_last()
app.list.select(Some(0));      // or set explicitly; selected() -> Option<usize>
let list = List::new(["a", "b", "c"]).highlight_symbol("> ");
frame.render_stateful_widget(list, area, &mut app.list);
```

`Table` works the same with `TableState` (tracks selected row + offset):

```rust
use ratatui::layout::Constraint;
use ratatui::style::{Style, Stylize};
use ratatui::widgets::{Cell, HighlightSpacing, Row, Table};
let table = Table::new(
        vec![Row::new(vec![Cell::from("ok"), Cell::from("42")])],
        [Constraint::Length(8), Constraint::Fill(1)],
    )
    .header(Row::new(vec!["name", "value"]).bold())
    .row_highlight_style(Style::new().reversed())   // renamed from highlight_style
    .highlight_spacing(HighlightSpacing::Always);
frame.render_stateful_widget(table, area, &mut app.table);
```

## Scrollbar

A `Scrollbar` is stateful; drive `ScrollbarState` from your own (position, content length):

```rust
use ratatui::widgets::{Scrollbar, ScrollbarOrientation, ScrollbarState};
let mut sb = ScrollbarState::new(content_len).position(offset);
frame.render_stateful_widget(
    Scrollbar::new(ScrollbarOrientation::VerticalRight),
    area,
    &mut sb,
);
```

## Charts and Canvas

```rust
use ratatui::symbols;
use ratatui::widgets::{Axis, Chart, Dataset, GraphType};
let pts = [(0.0_f64, 0.0_f64), (1.0, 2.0)];
let ds = Dataset::default()
    .marker(symbols::Marker::Braille)
    .graph_type(GraphType::Line)
    .data(&pts);
let chart = Chart::new(vec![ds])
    .x_axis(Axis::default().bounds([0.0, 1.0]))
    .y_axis(Axis::default().bounds([0.0, 2.0]));
```

```rust
use ratatui::style::Color;
use ratatui::widgets::canvas::{Canvas, Line as CanvasLine};
let cv = Canvas::default().paint(|ctx| {
    ctx.draw(&CanvasLine { x1: 0.0, y1: 0.0, x2: 10.0, y2: 10.0, color: Color::White });
});
```

## Custom widgets — pick the right trait

- **`impl Widget for &T`** — the default idiom. All built-ins implement `Widget` for their
  reference (since 0.26), so the caller keeps ownership and can render the same value twice.
- **`impl Widget for &mut T`** — when render must mutate the widget (e.g. cache layout).
- **`impl StatefulWidget for T`** — when the widget needs external, caller-owned state.

```rust
use ratatui::{buffer::Buffer, layout::Rect, text::Line, widgets::{StatefulWidget, Widget}};

struct Meter { pct: u16 }
impl Widget for &Meter {
    fn render(self, area: Rect, buf: &mut Buffer) {
        Line::from(format!("{}%", self.pct)).render(area, buf);
    }
}

struct Log;
struct LogState { offset: usize }
impl StatefulWidget for Log {
    type State = LogState;
    fn render(self, area: Rect, buf: &mut Buffer, state: &mut Self::State) {
        Line::from(format!("@{}", state.offset)).render(area, buf);
    }
}
```

Write into the buffer through `Line`/`Span`/`buf.set_string`/`buf[(x,y)]` — never raw ANSI
escapes; the diffing buffer must know each cell's content and style.

### WidgetRef is unstable

`WidgetRef`/`StatefulWidgetRef` (and `Frame::render_widget_ref`) are gated behind the
`unstable-widget-ref` feature — without it the trait is private and won't resolve. Only use
them if you opt in explicitly (`features = ["unstable-widget-ref"]`) and accept the
instability; otherwise `impl Widget for &T` covers the same need.

## Styling

`Style` + `Modifier` are the primitives, but the `Stylize` trait gives ergonomic
shorthands on strings and widgets. Text is **Span ⊂ Line ⊂ Text**; a parent's style is a
default that children patch.

```rust
use ratatui::style::{Modifier, Style, Stylize, palette::tailwind};
use ratatui::text::{Line, Span, Text};

let _ = "warn".yellow().on_black().bold().italic();
let styled = Span::styled("id", Style::new().fg(tailwind::SLATE.c400).add_modifier(Modifier::DIM));
let line = Line::from(vec![Span::raw("user: "), styled]).centered();
let _doc: Text = Text::from(vec![line, Line::raw("second")]);
```

The `line!`, `span!`, and `text!` macros ship via the default `macros` feature:

```rust
use ratatui::macros::{line, span, text};
let _l = line!["ok ", span!("done").green().bold()];
let _t = text!["row one", "row two"];
```

The `tailwind` palette (`ratatui::style::palette::tailwind::BLUE.c500`, etc.) gives a
ready, consistent color ramp. Enable the `serde` feature to load `Style`/`Color` from
config; the external `palette` crate integration is behind the `palette` feature.
