# Testing & debugging

MVU makes Bubble Tea unusually testable: `Update` is a pure function of `(state, msg)`, so
most logic needs no terminal at all.

## Prefer pure `Update` tests

Construct a model, feed it a message, assert on the returned state. Fast, deterministic, no
I/O. `Update` returns `tea.Model`, so type-assert back to your concrete type:

```go
func TestUpdateAppendsDelta(t *testing.T) {
	m := initialModel()
	updated, _ := m.Update(deltaMsg("hi"))
	if got := updated.(model).buf; got != "hi" {
		t.Fatalf("buf = %q, want %q", got, "hi")
	}
}
```

Test transitions (key → state change), command emission (assert the returned `Cmd` is
non-nil, or run it and inspect its `Msg`), and follow/freeze logic this way. This is the
bread-and-butter test; reach for the harness below only for end-to-end behavior.

## End-to-end with `teatest/v2`

`teatest` drives a whole program against an in-memory terminal. **Use the `/v2` path** —
`github.com/charmbracelet/x/exp/teatest/v2` — which imports `charm.land/bubbletea/v2`
(verified). The bare `…/x/exp/teatest` path is the **v1** harness and pulls in
bubbletea v1; mixing it with your v2 app fails to compile.

```go
import teatest "github.com/charmbracelet/x/exp/teatest/v2"

func TestQuitsOnQ(t *testing.T) {
	tm := teatest.NewTestModel(t, initialModel(), teatest.WithInitialTermSize(40, 10))
	tm.Send(tea.KeyPressMsg{Code: 'q'})
	tm.WaitFinished(t, teatest.WithFinalTimeout(2*time.Second))
}
```

Useful API: `NewTestModel`, `Send`, `Type`, `WaitFor(tb, r, cond)`, `WaitFinished`,
`FinalModel`, and `RequireEqualOutput` for golden tests (run with `-update` to refresh).
For stable goldens, force a fixed color profile (e.g. ASCII/no-color) so escape codes don't
vary by environment.

**Caveats — encode these honestly:**
- It lives under **`x/exp`**: explicitly *experimental*, no API-stability guarantee.
- It ships only as a **pseudo-version** (e.g. `v2.0.0-2026…`), so you pin a commit, not a
  release tag — `go get …/teatest/v2@latest` and record what resolved.

Because of that churn, keep the bulk of your coverage in pure `Update` tests and use
teatest for a thin layer of end-to-end smoke tests.

## Debugging

`fmt.Println`/`log` to stdout corrupts the alt-screen. Route logs to a file and `tail -f`:

```go
f, _ := tea.LogToFile("debug.log", "")
defer f.Close()
log.Println("got msg", msg)
```

Or pair `charm.land/log/v2` with that file writer for structured, leveled logs. To inspect
a frame without a terminal, render `m.View().Content` in a test and print/inspect the
string.
