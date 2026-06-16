# Text width, wrapping & markdown

The single most common terminal-UI bug: assuming one `byte` or one `rune` is one column.
It isn't. CJK ideographs and many emoji are **two** columns; combining marks are **zero**;
a ZWJ emoji (👩‍👩‍👧) or a flag is several runes but renders in ~two columns. Misjudge width
and your borders, truncation, and alignment all drift.

## Measure and slice by display width

Use `charmbracelet/x/ansi` — it is ANSI-escape-aware (won't cut a color code in half) and
width-aware. It's the same engine Lip Gloss measures with, so `ansi.StringWidth(s) ==
lipgloss.Width(s)`.

```go
import "github.com/charmbracelet/x/ansi"

w := ansi.StringWidth(s)            // display columns (NOT len(s) or utf8.RuneCountInString)
head := ansi.Truncate(s, 20, "…")   // truncate to 20 cols, append ellipsis, keep ANSI intact
tail := ansi.TruncateLeft(s, 20, "…")
mid := ansi.Cut(s, 5, 25)           // slice by columns [5,25)
wrapped := ansi.Wrap(long, 40, "")  // wrap at 40 cols (breakpoints arg optional)
hard := ansi.Hardwrap(long, 40, false) // hard wrap ignoring word boundaries
plain := ansi.Strip(s)              // drop all ANSI escapes
```

The `…Wc` variants (`StringWidthWc`, `TruncateWc`, …) use stricter wide-character rules for
edge cases. **Footgun:** `ansi.StringWidth` only measures correctly on whole strings —
feeding it one rune at a time mis-handles graphemes that span runes, so accumulate then
measure.

## Graphemes

When you must iterate "user-perceived characters" (cursor movement, selection), cluster by
grapheme, not rune, via `rivo/uniseg`:

```go
import "github.com/rivo/uniseg"

n := uniseg.GraphemeClusterCount(s) // number of grapheme clusters
w := uniseg.StringWidth(s)          // monospace display width

g := uniseg.NewGraphemes(s)         // iterate clusters
for g.Next() {
	cluster := g.Str() // a full grapheme, e.g. the whole "👩‍👧" not its pieces
	_ = cluster
}
```

## Markdown via Glamour

`charm.land/glamour/v2` renders Markdown to styled terminal text. Two entry points:

```go
out, _ := glamour.Render(md, "dark") // quick: input + built-in style name

r, _ := glamour.NewTermRenderer(      // configurable
	glamour.WithStandardStyle("dark"),
	glamour.WithWordWrap(80),
)
out, _ = r.Render(md)
```

**Streaming caveat:** Glamour buffers the **entire** input and re-renders it — it has no
incremental mode. While tokens arrive, the Markdown is often syntactically incomplete (an
unclosed code fence, a half-written list), so re-rendering every delta **flickers** and can
reflow. Mitigations: re-render the accumulated buffer on a throttled tick rather than per
token; or render plain text while streaming and only run Glamour once the block is
complete. See `agent-ui.md` for the throttled-render loop.
