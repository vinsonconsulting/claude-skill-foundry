# The Charm ecosystem & versions

The whole stack moved to v2 together (Feb 2026) on the **`charm.land/*/v2`** vanity paths.
Versions below are what `@latest` resolved to during this skill's compile-check — re-check a
module's tag before depending on it, but **never mix `github.com/charmbracelet/...` import
paths with `charm.land/...`** in one module: that pulls two copies of a package and breaks
type identity.

## Libraries (verified)

| Module | Version | What it is |
| --- | --- | --- |
| `charm.land/bubbletea/v2` | v2.0.7 | The MVU runtime. |
| `charm.land/lipgloss/v2` | v2.0.4 | Styling + layout (joins, place, canvas/layers, color). |
| `charm.land/bubbles/v2` | v2.1.0 | Reusable components (viewport, list, table, inputs, …). |
| `charm.land/glamour/v2` | v2.0.1 | Markdown → styled terminal text. |
| `charm.land/huh/v2` | v2.0.3 | Forms & prompts; usable standalone or inside a Bubble Tea app. |
| `charm.land/wish/v2` | v2.0.1 | Serve Bubble Tea apps over SSH. |
| `charm.land/log/v2` | v2.0.0 | Structured, styled logger (pairs with `tea.LogToFile`). |

Supporting (transitive, but you'll import some directly):

| Module | Role |
| --- | --- |
| `github.com/charmbracelet/x/ansi` | ANSI-aware width/wrap/truncate (see `text-and-unicode.md`). |
| `github.com/charmbracelet/ultraviolet` | The renderer ("Cursed Renderer") backing Bubble Tea v2. |
| `github.com/charmbracelet/colorprofile` | Terminal color-capability detection + downsampling. |
| `github.com/rivo/uniseg` | Grapheme clustering + monospace width. |

These four stay on `github.com/charmbracelet/...` — they have no `charm.land` alias and no
`/v2`; that's expected, not the import trap. The trap is specifically the
**`bubbletea`/`lipgloss`/`bubbles`/`glamour`/`huh`/`wish`/`log`** packages, which must come
from `charm.land/*/v2`.

## Tools (not imports)

Companions you run, not link: **gum** (shell scripting with Charm widgets), **vhs**
(record terminal GIFs for docs/tests), **mods** (LLM CLI, streams Markdown), **glow**
(Markdown pager), **soft-serve** (Git server over SSH, built on Wish).

## Exemplars worth reading

- **`charmbracelet/crush`** — the reference large app: a single top-level `tea.Model`,
  pubsub→`program.Send` bridge, width-keyed render cache (the `agent-ui.md` and
  `components.md` patterns are drawn from it). Verify specifics against the live repo before
  treating internal names as fact.
- **`charmbracelet/bubbletea` `examples/`** — version-correct v2 snippets; `realtime`,
  `chat`, and `composable-views` are closest to streaming/agent UIs. `tutorials/` has the
  guided v2 walkthrough.
- **`mods`** and **`glow`** — streaming Markdown rendering in practice.
- **`soft-serve`** — Wish + multi-screen navigation.
