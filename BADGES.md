# Badge serving (R2)

Shields.io **endpoint** badge JSON for every carded skill, generated in CI and
served from a public Cloudflare R2 bucket. The R2 key layout matches the future
Discover Worker route (Califa SPEC §G: `GET /badge/<name>/<metric>.json`), so the
Worker can serve these same objects later with no migration.

## Bucket

|                 |                                                                  |
| --------------- | ---------------------------------------------------------------- |
| Bucket          | `califa-badges` (R2, account `1707f13c…`)                        |
| Public base URL | `https://pub-71c1a161b82140039deed518bba2d659.r2.dev`            |
| Access          | public `r2.dev` development URL (non-production, rate-limited)    |
| Key layout      | `<name>/<metric>.json`                                            |

A custom domain (cache + WAF) is an optional later upgrade; the `r2.dev` URL is
sufficient for shields, which fetches the endpoint server-side.

## Metrics

Five per carded skill (Califa SPEC §F): `scan`, `trigger`, `tasks`, `signed`,
`card`. Beta cards (no metrics) emit a valid neutral grey `n/a` for `trigger` and
`tasks` — still valid JSON, still HTTP 200.

## How it's published

`.github/workflows/badges.yml` runs on push to `main` (and `workflow_dispatch`):
it generates each carded skill's badges with `skillcard badges` (vendored Califa
≥ v0.8.0) into a staging dir **outside** `skills/`, then uploads each file to R2
as `<name>/<metric>.json` with `--content-type application/json --remote`.

R2 auth uses the GitHub Actions secrets **`CLOUDFLARE_ACCOUNT_ID`** and
**`CLOUDFLARE_API_TOKEN`** (token scoped to *Workers R2 Storage: Edit*). No secret
is committed to the repo.

## Using a badge

Endpoint badge URL form:

```
https://img.shields.io/endpoint?url=https://pub-71c1a161b82140039deed518bba2d659.r2.dev/<name>/<metric>.json
```

Example (ratatui `scan`):

```markdown
![scan](https://img.shields.io/endpoint?url=https://pub-71c1a161b82140039deed518bba2d659.r2.dev/ratatui/scan.json)
```

Direct JSON: `https://pub-71c1a161b82140039deed518bba2d659.r2.dev/ratatui/scan.json`

## Skills served

Public-cabinet carded skills only: `ratatui`, `bubbletea`, `textual`,
`image-to-ascii` (4 × 5 = 20 objects).

## Follow-ons (not done here)

- Switch the cabinet READMEs from static `img.shields.io/badge/…` to these
  endpoint badges (the `scripts/cardkit.py` + marker machinery).
- Private-cabinet badge serving is separate and deferred — **never** this public
  bucket (private cards must not be exposed publicly).
