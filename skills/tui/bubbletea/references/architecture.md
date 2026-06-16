# Architecture: MVU, commands, events, lifecycle

The deep version of the body. Everything here is verified against bubbletea **v2.0.7**.

## MVU in one paragraph

The runtime holds your `Model`. On each message it calls `Update(msg)` → `(Model, Cmd)`,
stores the returned model, runs any returned `Cmd` in a goroutine, then calls `View()` and
paints. Your code never calls `Update`/`View` itself and never drives a loop — that is the
runtime's job. The single rule that makes this safe: **`Update` is the only place state
changes.** `View` is pure (read-only); a `Cmd` body and any goroutine you spawn must not
touch the model — they communicate by returning/sending a `Msg`.

## Commands

A `Cmd` is `func() tea.Msg`. The runtime runs it concurrently and feeds its result back
into `Update`. Constructors:

- `tea.Batch(a, b, …)` — run cmds **concurrently**; their msgs arrive in any order.
- `tea.Sequence(a, b, …)` — run cmds **in order**, each after the previous completes.
- `tea.Tick(d, fn)` — fire once after `d`; re-issue it from `Update` for a repeating clock.
- `tea.Every(d, fn)` — fire aligned to wall-clock multiples of `d`.
- `tea.Quit` — a `Cmd` (it is `func() Msg`); **return it, do not call it**: `return m, tea.Quit`.

Do blocking work (HTTP, disk, subprocess) inside a `Cmd`, never in `Update`:

```go
func fetch(url string) tea.Cmd {
	return func() tea.Msg {
		resp, err := http.Get(url)
		if err != nil {
			return errMsg{err}
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		return loadedMsg(body) // arrives back in Update
	}
}
```

## Messages

`tea.Msg` is `any` (alias of `ultraviolet.Event`, an empty interface), so **any type is a
message**. Define your own as plain types. The runtime also delivers built-ins you switch
on: `WindowSizeMsg`, key messages, mouse messages, `FocusMsg`/`BlurMsg`,
`BackgroundColorMsg`, `PasteMsg`, etc. You are responsible for routing built-ins down into
child components.

```go
case tea.WindowSizeMsg:        // one at startup, then on every resize
	m.w, m.h = msg.Width, msg.Height
	m.list.SetSize(msg.Width, msg.Height-2)
```

## Keys (v2 taxonomy)

v2 replaced v1's single `KeyMsg` struct (`.Type`/`.Runes`) with **two concrete types and an
interface**:

- `tea.KeyPressMsg` and `tea.KeyReleaseMsg` (both defined as `tea.Key`).
- `tea.KeyMsg` is an **interface** (`fmt.Stringer` + `Key() Key`) that matches both.

Releases arrive only if you enable keyboard enhancements; the common case is
`KeyPressMsg`. The `Key` struct:

```go
type Key struct {
	Text        string // printable chars actually entered ("a", "A", "!"); empty for special keys
	Mod         KeyMod // modifier bitmask
	Code        rune   // the key: 'a', or a special like KeyTab/KeyEnter/KeyF1
	ShiftedCode rune   // shifted value (Kitty/Windows only)
	BaseCode    rune   // PC-101 layout value (Kitty/Windows only)
	IsRepeat    bool   // held-down repeat (Kitty/Windows only)
}
```

Two idiomatic match styles — string (shorter) or `Code` (foolproof):

```go
func handleKey(msg tea.KeyPressMsg) string {
	if msg.Mod.Contains(tea.ModCtrl) { // modifiers via Mod.Contains
		return "ctrl+" + msg.String()
	}
	switch msg.Key().Code {
	case tea.KeyTab:
		return "tab"
	case tea.KeyEsc:
		return "esc"
	case tea.KeyEnter:
		return "enter"
	}
	return msg.String() // "a", "ctrl+c", "shift+left", and notably "space"
}
```

**Space is `"space"`, not `" "`** (verified: `tea.Key{Code: ' '}.String() == "space"`).

## Mouse (v2 taxonomy)

v1's single `MouseMsg` struct (`.Action`/`.Button`) is gone. v2 has concrete
`MouseClickMsg`, `MouseReleaseMsg`, `MouseWheelMsg`, `MouseMotionMsg` (each defined as
`tea.Mouse`) plus a `MouseMsg` interface (`Mouse() Mouse`) for catch-all handling:

```go
func handleMouse(msg tea.Msg) {
	switch msg := msg.(type) {
	case tea.MouseClickMsg:
		m := msg.Mouse() // Mouse{ X, Y int; Button MouseButton; Mod KeyMod }
		if m.Button == tea.MouseLeft {
			// click at (m.X, m.Y)
		}
	case tea.MouseWheelMsg:
		_ = msg.Mouse().Y // scroll
	}
}
```

Mouse is off until you set `v.MouseMode` on the returned `View` (see lifecycle).

## Lifecycle & ProgramOptions

```go
p := tea.NewProgram(initialModel())
if _, err := p.Run(); err != nil { // Run returns (final Model, error)
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
```

Alt-screen and mouse are **`tea.View` fields**, not options (see the body). The remaining
real `ProgramOption`s are: `WithContext`, `WithInput`, `WithOutput`, `WithEnvironment`,
`WithFilter`, `WithFPS`, `WithColorProfile`, `WithWindowSize`, and the opt-outs
`WithoutCatchPanics`, `WithoutRenderer`, `WithoutSignalHandler`, `WithoutSignals`. There is
**no** `WithAltScreen`/`WithMouseCellMotion`.

**Panic safety is automatic.** By default the runtime recovers panics, restores the
terminal, and returns `tea.ErrProgramPanic` from `Run()` (other sentinels:
`ErrInterrupted`, `ErrProgramKilled`). `WithoutCatchPanics` disables this. Never hand-roll
raw mode/teardown — the renderer (the "Cursed Renderer", backed by
`charmbracelet/ultraviolet`) owns the alt-screen and cursor. (Charm markets the renderer as
"~10× faster" than v1 — treat that as a vendor claim, not a measured guarantee.)

## Logging

stdout is the UI. Logging there corrupts the screen. Redirect to a file at startup and
`tail -f` it:

```go
f, err := tea.LogToFile("debug.log", "")
if err != nil { /* handle */ }
defer f.Close()
log.Println("startup")
```
