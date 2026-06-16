# Versioning, module paths & migration

## Pin & toolchain (verified by compile-check)

- **bubbletea v2.0.7**, **lipgloss v2.0.4**, **bubbles v2.1.0**, **glamour v2.0.1** — pin
  the `v2` major and let patches flow.
- **Go floor `go 1.25.0`** — verbatim in bubbletea's and lipgloss's `go.mod`. Your module's
  `go` directive must be ≥ 1.25.0.
- Wider stack (also v2): **huh v2.0.3**, **wish v2.0.1**, **log v2.0.0**.

## The import-path trap

| Path | Status |
| --- | --- |
| `charm.land/bubbletea/v2` (and `lipgloss`/`bubbles`/`glamour`/`huh`/`wish`/`log` `…/v2`) | **Canonical** final v2. Use these. |
| `github.com/charmbracelet/bubbletea/v2` | **Beta-only** path. Do not use; mixing with `charm.land` breaks `go.mod`. |
| `github.com/charmbracelet/bubbletea` (no `/v2`) | **v1.** Legacy. |
| `github.com/charmbracelet/x/ansi`, `…/ultraviolet`, `colorprofile`, `rivo/uniseg` | Stay on `github.com`; no `charm.land` alias. Importing these is fine. |

Keep every Charm *framework* package on `charm.land/*/v2`. One stray `github.com/...v2`
import pulls a second copy and the types stop matching.

## v1 → v2 migration map

The API the model "remembers" is usually v1. Translate:

| v1 | v2 |
| --- | --- |
| `import "github.com/charmbracelet/bubbletea"` | `import tea "charm.land/bubbletea/v2"` |
| `View() string` | `View() tea.View` (`tea.NewView(s)`; children still return `string`) |
| `tea.NewProgram(m, tea.WithAltScreen())` | return a `View` with `v.AltScreen = true` |
| `tea.WithMouseCellMotion()` / `WithMouseAllMotion()` | `v.MouseMode = tea.MouseModeCellMotion` / `MouseModeAllMotion` |
| `KeyMsg` struct; `msg.Type == tea.KeyEnter`; `msg.Runes` | `KeyPressMsg`/`KeyReleaseMsg` (+ `KeyMsg` iface); `msg.Key().Code` / `msg.String()` / `msg.Text` |
| matching space as `" "` | `"space"` |
| `MouseMsg` struct; `.Action` / `.Button` | `MouseClickMsg`/`MouseReleaseMsg`/`MouseWheelMsg`/`MouseMotionMsg`; `msg.Mouse()` |
| `viewport.New(w, h)` | `viewport.New(viewport.WithWidth(w), viewport.WithHeight(h))` |
| built-in `lipgloss.AdaptiveColor{...}` | `compat.AdaptiveColor` **or** `tea.RequestBackgroundColor` + `BackgroundColorMsg.IsDark()` |
| `teatest` (`x/exp/teatest`) | `x/exp/teatest/v2` |

**Unchanged from v1 — do not "modernize":** `Init() Cmd` and `Update(Msg) (Model, Cmd)`.
The *only* `Model` signature that changed is `View`.

## Deltas found while verifying against v2.0.7

These corrected the starting research during the live compile-check — trust the installed
modules over older notes:

- **`Init() Cmd`, not `Init() (Model, Cmd)`.** Init is unchanged from v1; the lone interface
  change is `View() string → View() tea.View`. So `Init() tea.Cmd` is **correct** and must
  not be flagged as stale.
- **`tea.View` is a struct, not an interface.** Build it with `tea.NewView(s)` / `v.SetContent(s)`;
  fields include `Content`, `AltScreen`, `MouseMode`, `Cursor`, `BackgroundColor`,
  `WindowTitle`, `ProgressBar`, `OnMouse`. Child components still return plain `string`.
- **`viewport.New` takes functional options** (`WithWidth`/`WithHeight`), not positional
  width/height.
- **`teatest/v2` is compatible** with `charm.land/bubbletea/v2` — it imports that path and
  the tests pass. (Earlier worry that it lagged v2 was unfounded; the `/v2` suffix is the
  catch.)
- **Canvas/layers are a Lip Gloss feature** (`lipgloss.NewCanvas`/`NewLayer`). There is no
  `tea.Layer`.
- **Resolved version is v2.0.7** (settling the v2.0.2-vs-v2.0.7 ambiguity in the source
  research).
