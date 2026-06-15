# Layout

Ratatui layout is constraint-solving over rectangles (the solver is the first-party
`kasuari` crate — you never name it). You give a parent `Rect` and a list of
`Constraint`s; the solver returns child `Rect`s. All coordinates are `u16`.

## Two APIs: `.areas()` vs `.split()`

```rust
use ratatui::layout::{Constraint, Layout};

// compile-time count — destructure into a fixed-size array. Prefer this.
let [left, right] = Layout::horizontal([Constraint::Fill(1), Constraint::Length(20)])
    .areas(area);

// dynamic count — returns Rc<[Rect]>; index it. Use when N isn't known at compile time.
let rows = Layout::vertical([Constraint::Length(1)].repeat(n)).split(area);
let first = rows[0];
```

`Layout::vertical([..])` and `Layout::horizontal([..])` are the modern constructors.
The older `Layout::default().direction(Direction::Vertical).constraints([..]).split(area)`
still works and is what you'll see in pre-0.26 code; both compile on 0.30.

## The six constraints

| Constraint | Meaning |
| --- | --- |
| `Length(u16)` | exactly this many cells (clamped to available) |
| `Percentage(u16)` | percent of the parent length |
| `Ratio(num, den)` | fraction `num/den` of the parent |
| `Min(u16)` | at least this many; grows to absorb leftover space |
| `Max(u16)` | at most this many |
| `Fill(u16)` | takes leftover space, split between `Fill`s by weight |

`Fill` **replaces** the old `Proportional`. There is no `Proportional` in 0.30.

When constraints compete for the same cells, the solver honors this priority:
**`Min` > `Max` > `Length` > `Percentage` > `Ratio` > `Fill`**. So a `Min`/`Max`
pins a band and `Fill`/`Percentage` divide what's left. Mixing `Length` + `Fill` is the
everyday "fixed sidebar, elastic main" pattern.

## Flex: distributing leftover space

When the constraints don't consume the whole parent (e.g. three `Length(10)` in a
width-60 area leaves 30 cells), `Flex` decides where the slack goes. **The default is
`Flex::Start`** — items pack to the start, slack at the end. There is no `StretchLast`
and no `SegmentSize` (both removed).

```rust
use ratatui::layout::Flex;
Layout::horizontal([Constraint::Length(10), Constraint::Length(10)])
    .flex(Flex::SpaceBetween);   // Start | End | Center | SpaceBetween | SpaceAround | Legacy
```

`Flex::Legacy` reproduces the old stretch-the-last-segment behavior if you truly need it.

## Spacing, margins, inner

```rust
use ratatui::layout::{Constraint, Layout, Margin};
Layout::horizontal([Constraint::Fill(1), Constraint::Fill(1)]).spacing(1); // gap between items
Layout::vertical([Constraint::Length(3)]).margin(1);                        // outer margin all sides
Layout::vertical([Constraint::Length(3)]).horizontal_margin(2).vertical_margin(1);
let content = area.inner(Margin::new(2, 1));   // shrink a Rect by (horizontal, vertical) cells
```

`Block` also produces an inner area via `block.inner(area)` — render the block, then lay
out inside `block.inner(area)`.

## Centering and popups

`Rect` has first-class centering helpers (cleaner than the old hand-rolled `centered_rect`):

```rust
use ratatui::layout::Constraint;
let popup = area.centered(Constraint::Percentage(60), Constraint::Length(10)); // (horizontal, vertical)
let bar   = area.centered_horizontally(Constraint::Length(40));
let mid   = area.centered_vertically(Constraint::Length(3));
```

Equivalent via `Flex::Center` if you prefer composing layouts:

```rust
use ratatui::layout::{Constraint, Flex, Layout};
let [h] = Layout::horizontal([Constraint::Length(40)]).flex(Flex::Center).areas(area);
let [popup] = Layout::vertical([Constraint::Length(10)]).flex(Flex::Center).areas(h);
```

Always `frame.render_widget(Clear, popup)` before drawing the popup, or the content
underneath shows through.

## Nested layouts & responsiveness

Split top-level regions first, then split each region independently — layouts compose by
feeding one child `Rect` into the next `Layout`. Because you rebuild layout every frame
from `frame.area()`, responsiveness is automatic: branch on `area.width`/`area.height`
to pick a different constraint set for narrow terminals.

```rust
let cols = if area.width < 80 {
    Layout::vertical([Constraint::Fill(1), Constraint::Fill(1)]) // stack on narrow
} else {
    Layout::horizontal([Constraint::Fill(1), Constraint::Fill(1)]) // side-by-side on wide
};
```

## Layout cache

Layout solving is memoized (the `layout-cache` feature is on by default), so re-solving
the same constraints each frame is cheap. You don't manage the cache; just don't fight it
by allocating fresh `Constraint` vectors needlessly in hot paths — prefer arrays.
