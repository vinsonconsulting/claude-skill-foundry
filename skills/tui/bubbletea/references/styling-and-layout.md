# Styling & layout with Lip Gloss

Lip Gloss (v2, `charm.land/lipgloss/v2`) is how you style and arrange text. There is **no
constraint solver** — you render styled blocks and compose them as strings. Sizes come from
`tea.WindowSizeMsg`; you do the arithmetic.

## Styles

A `Style` is an immutable, chainable set of attributes; `.Render(s)` applies it:

```go
box := lipgloss.NewStyle().
	Bold(true).
	Foreground(lipgloss.Color("#7D56F4")).      // hex, ANSI-256 ("236"), or named
	Background(lipgloss.Color("236")).
	Border(lipgloss.RoundedBorder()).            // Normal/Rounded/Double/Block/ASCII/Hidden…
	Padding(1, 2).                               // (vertical, horizontal); also Margin, Width, Height
	Align(lipgloss.Center).
	Render("hello")
```

Width/height set the block size; `lipgloss.Width(s)` / `lipgloss.Height(s)` /
`lipgloss.Size(s)` **measure** rendered output (display columns, ANSI-aware) — always use
these over `len()`.

## Color in v2 — "pure", profile-aware

v2 colors are `color.Color` values (from the stdlib `image/color`). Lip Gloss no longer
queries the terminal itself; **Bubble Tea owns I/O** and feeds the detected profile, so
color downsampling to the terminal's capability happens automatically via
`charmbracelet/colorprofile`. You just pick colors; the runtime degrades them.

For light/dark adaptation, two options:

```go
// 1. Static adaptive color (resolved by background darkness):
import "charm.land/lipgloss/v2/compat"
c := compat.AdaptiveColor{Light: lipgloss.Color("236"), Dark: lipgloss.Color("252")}

// 2. Preferred: ask the terminal, then branch in your model.
func (m model) Init() tea.Cmd { return tea.RequestBackgroundColor }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if msg, ok := msg.(tea.BackgroundColorMsg); ok {
		m.dark = msg.IsDark() // choose your palette from this
	}
	return m, nil
}
```

Option 2 keeps color choices in your model (testable, no global state) and is the v2-idiomatic path.

## Composition & placement

Glue blocks with joins; center/position within a region with `Place`:

```go
// 30-cell sidebar + flexible main, with header and footer
sidebar := lipgloss.NewStyle().Width(30).Render(nav)
main := lipgloss.NewStyle().Width(totalW - 30).Render(content)   // total - sidebar
body := lipgloss.JoinHorizontal(lipgloss.Top, sidebar, main)      // align tops
ui := lipgloss.JoinVertical(lipgloss.Left, header, body, footer)

// center a popup inside the full screen
centered := lipgloss.Place(totalW, totalH, lipgloss.Center, lipgloss.Center, popup)
```

Position constants (`Top`, `Bottom`, `Left`, `Right`, `Center`) are `Position` floats in
`[0.0, 1.0]`, so `lipgloss.Position(0.25)` is a quarter-way alignment. `PlaceHorizontal` /
`PlaceVertical` place along one axis.

## Overlays: Canvas & Layers

For true overlapping/absolute positioning (a popup *on top of* content, not joined beside
it), use the z-indexed canvas. Layers carry an `X/Y/Z` and the canvas composites them:

```go
c := lipgloss.NewCanvas(totalW, totalH)
base := lipgloss.NewLayer(backgroundUI)
popup := lipgloss.NewLayer(box).X(10).Y(4).Z(1)  // higher Z draws on top
c.Compose(base)
c.Compose(popup)
out := c.Render()
```

This is the v2 replacement for the old "render Clear then the popup" dance — layers handle
the occlusion. Use joins/`Place` for flow layout, the canvas for overlapping UI.
