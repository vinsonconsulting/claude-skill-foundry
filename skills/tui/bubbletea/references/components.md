# Components (Bubbles) & scaling

Bubbles are the official reusable components, each at `charm.land/bubbles/v2/<name>`. Every
one is a `Model` (`Init`/`Update`/`View`), so they nest the same way your app does.

## Catalog (v2)

| Package | What it is / state you keep |
| --- | --- |
| `viewport` | Scrollable region; owns scrollback. `SetContent`, `AtBottom`, `GotoBottom` (see agent-ui). |
| `list` | Filterable, paginated, selectable list with a delegate-driven row renderer. |
| `table` | Scrollable rows/columns with a selected row. |
| `textinput` | Single-line input (cursor, placeholder, validation). |
| `textarea` | Multi-line editor. |
| `spinner` | Animated spinner; tick-driven. |
| `progress` | Progress bar (animated or static). |
| `paginator` | Page indicator + page math. |
| `help` | Renders short/full help from a `key.Map`. |
| `key` | `key.Binding` + `key.Matches(msg, binding)` for declarative keymaps. |
| `filepicker` | Filesystem browser. |
| `stopwatch` / `timer` | Elapsed / countdown, tick-driven. |
| `cursor` | The blinking cursor primitive used by inputs. |

## The nesting contract

Hold the child's model in your struct; forward messages (including `WindowSizeMsg`),
reassign what `Update` returns, and bubble the `Cmd` up:

```go
import "charm.land/bubbles/v2/list"

type listItem struct{ title, desc string }

func (i listItem) Title() string       { return i.title }
func (i listItem) Description() string { return i.desc }
func (i listItem) FilterValue() string { return i.title } // list.Item requires this

type model struct{ list list.Model }

func newModel() model {
	items := []list.Item{listItem{"alpha", "first"}, listItem{"beta", "second"}}
	return model{list: list.New(items, list.NewDefaultDelegate(), 40, 12)}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.list.SetSize(msg.Width, msg.Height) // forward the size down
	case tea.KeyPressMsg:
		if msg.String() == "enter" {
			_ = m.list.SelectedItem() // act on selection
		}
	}
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg) // reassign + bubble Cmd
	return m, cmd
}

func (m model) View() tea.View { return tea.NewView(m.list.View()) }
```

`textinput` follows the identical shape (`ti := textinput.New(); ti.Focus()` returns a
`Cmd` to start the cursor blink).

## Authoring your own Bubble

Match the convention so it composes: a `New` constructor and `Init`/`Update`/`View`, where
`Update` returns the **concrete** type (not `tea.Model`) and `View` returns `string`:

```go
type counter struct{ n int }

func New() counter             { return counter{} }
func (c counter) Init() tea.Cmd { return nil }
func (c counter) Update(msg tea.Msg) (counter, tea.Cmd) { // concrete return type
	if k, ok := msg.(tea.KeyPressMsg); ok && k.String() == "+" {
		c.n++
	}
	return c, nil
}
func (c counter) View() string { return fmt.Sprintf("%d", c.n) }
```

Returning the concrete type (the same choice the official Bubbles make) lets a parent write
`m.counter, cmd = m.counter.Update(msg)` without a type assertion. Side effects go through
a `Cmd`; keep package-global mutable state out.

## The Crush escape hatch (scaling past the fan-out)

Pure nesting means every message type-switches through every level of `Update`. In a large
app (many panes, dialogs, a status bar) that fan-out becomes the bulk of your code. The
pattern Crush uses: keep **one** top-level `tea.Model` that the runtime drives, but make
sub-components plain stateful structs with **imperative methods** (called directly from the
parent's `Update`) that return `tea.Cmd` — not a full `Update`/`Msg` dance:

```go
type pane struct {
	items []string
	sel   int
}

func (p *pane) moveDown() tea.Cmd { // imperative; pointer receiver mutates in place
	if p.sel < len(p.items)-1 {
		p.sel++
	}
	return nil // return a Cmd when the action needs async work
}
func (p *pane) view() string { return p.items[p.sel] }

// parent Update calls p.moveDown() directly on a key, batching any returned Cmds.
```

This keeps the single-writer guarantee (the parent's `Update` still owns all mutation —
it's the only caller) while avoiding a deep `Update` tree. Reach for it only when the
fan-out actually hurts; small apps are clearer with plain nesting.
