# Streaming LLM/agent output into Bubble Tea

**Scope:** the *Bubble Tea* side of a streaming chat/agent TUI — getting deltas into the
loop safely, following vs. freezing, and not melting the CPU re-rendering. **Out of scope:**
agent *orchestration* — tmux multiplexing, multi-session supervision, JSONL transcript
parsing, process trees. That is a separate skill; do not build it here.

## The one safe channel in: `p.Send`

The model is single-writer (only `Update` mutates it). A producer goroutine therefore may
**not** touch the model, call `m.Update`, or call `viewport.Update`. Its *only* legal move
is `p.Send(msg)`, which is goroutine-safe and non-blocking (and a no-op after the program
exits). Everything else races the renderer.

```go
type deltaMsg string

// Capture *tea.Program once (from main), then stream from a goroutine:
func stream(p *tea.Program, tokens <-chan string) {
	go func() {
		for t := range tokens {
			p.Send(deltaMsg(t)) // never read/write m or vp here
		}
	}()
}
```

`tea.Listen` is a **proposal, not a real API** — don't reach for it. `Cmd` + `p.Send` is
the whole concurrency story; you rarely need extra machinery.

## Follow-vs-freeze scrollback

The `viewport` Bubble owns scrollback (don't hand-roll a ring buffer). Auto-follow only when
the user is already pinned to the bottom; the moment they scroll up, stop following:

```go
// Build the viewport with functional options (v2) — not positional viewport.New(w, h):
func newModel() model {
	return model{vp: viewport.New(viewport.WithWidth(80), viewport.WithHeight(24))}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case deltaMsg:
		atBottom := m.vp.AtBottom() // sample BEFORE changing content
		m.buf += string(msg)
		m.vp.SetContent(m.render(m.vp.Width(), m.buf)) // see cache below
		if atBottom {
			m.vp.GotoBottom() // follow only if we were pinned
		}
	case tea.WindowSizeMsg:
		m.vp.SetWidth(msg.Width)
		m.vp.SetHeight(msg.Height - 2)
		m.vp.SetContent(m.render(msg.Width, m.buf)) // re-render at the new width
	}
	return m, nil
}
```

For token streaming that extends the current line, appending to `m.buf` and re-`SetContent`
is the simplest correct approach; the cache keeps it cheap.

## Decoupling the domain: a pubsub → `Send` bridge

Crush's structure: the domain layer (sessions, tools, model calls) publishes events on an
in-process bus and knows nothing about the UI. A single goroutine subscribes and forwards
each event into the loop with `p.Send`. The UI never reaches into the domain, and the domain
never reaches into the UI.

```go
type bus struct{ subs []chan busEvent }

func (b *bus) subscribe() <-chan busEvent { /* append a buffered chan, return it */ }

func bridge(p *tea.Program, b *bus) {
	go func() {
		for ev := range b.subscribe() {
			p.Send(deltaMsg(ev.data)) // translate domain event → UI Msg
		}
	}()
}
```

## Width-keyed render cache

Re-running Glamour or width-aware wrapping on every delta is the usual performance sink.
Cache the rendered output keyed by `(width, content)` and skip the work when neither
changed — re-render only when a delta lands or the terminal resizes:

```go
type renderCache struct {
	width int
	key   string
	out   string
}

func (rc *renderCache) render(width int, content string, fn func(int, string) string) string {
	if rc.width == width && rc.key == content {
		return rc.out
	}
	rc.width, rc.key, rc.out = width, content, fn(width, content)
	return rc.out
}
```

Keying on width matters because a resize invalidates wrapped output even when the text is
unchanged. For Markdown, pair this with the throttled re-render from `text-and-unicode.md`
so a fast stream doesn't reflow Glamour on every token.
