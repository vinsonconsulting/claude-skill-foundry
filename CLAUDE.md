# CLAUDE.md

This repo is a skills monorepo: each skill is a folder under
`skills/<category>/<name>/` with a `SKILL.md` (YAML frontmatter `name` +
`description`, then instructions).

## Working here

- Add a skill: `cp -r skills/_TEMPLATE skills/<category>/<name>`, edit
  `SKILL.md`, run `make check`.
- `make lint` validates frontmatter and refs. `make index` regenerates the
  README table. Never hand-edit the table between the `SKILLS-INDEX` markers.
- Folders under `skills/` starting with `_` are ignored by the tooling.
- No secrets in any skill. Reference where they live.

CI (`.github/workflows/validate.yml`) runs lint plus `build_index.py --check`,
so a stale index fails the build.
