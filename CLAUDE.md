# CLAUDE.md

This repo is a library of Claude skills. Each skill is a self-contained folder
under `skills/<category>/<name>/` holding a `SKILL.md` plus any `scripts/`,
`references/`, or `assets/` it needs. The goal is skills that trigger reliably and
are portable: clone the repo, copy a folder, and it works anywhere Claude reads
skills.

## How a skill loads (progressive disclosure)
Claude reads skills in three tiers, cheap to expensive. Author with this in mind:
1. **Metadata** (always loaded): the `name` and `description` from every skill's
   frontmatter. This is the only thing Claude sees by default, so the description
   is what decides whether the skill fires. Keep it dense with triggers.
2. **Body** (loaded when the skill fires): the Markdown in `SKILL.md`. Keep it
   under ~500 lines. It's instructions for Claude, not documentation for humans.
3. **Bundled files** (loaded on demand): `references/`, `scripts/`, `assets/`.
   Push anything long, rarely needed, or reference-like out of the body into these.

## The description is the trigger
Under-triggering is the dominant failure mode: Claude tends not to invoke a skill
that would have helped. So the `description` must state, concretely, **when** to
use the skill, in the third person, with the words a user would actually use. Lead
with the trigger conditions, then what it does. Be a little pushy. "Use when the
user wants to X, mentions Y, or is working with Z" beats "A skill for X."

## Authoring conventions
- One concern per skill. If a SKILL.md sprouts a second job, split it.
- Write the body as imperative instructions to Claude. Explain *why* a step
  matters rather than shouting MUSTs; Claude follows reasoning better than emphasis.
- Keep the body lean; move detail to `references/`. Bundle a `scripts/` helper when
  the same deterministic step recurs, so Claude doesn't re-derive it each time.
- `skills/<category>/<name>/SKILL.md` is the path contract. Frontmatter needs
  `name` (matching the folder) and `description`.
- Folders under `skills/` that start with `_` (like `_TEMPLATE`) are ignored by
  the tooling.
- No secrets in any skill. Reference where they live instead.

## Build and check
- New skill: `./tools/new-skill.sh <category> <name>` (or
  `cp -r skills/_TEMPLATE skills/<category>/<name>`), then edit `SKILL.md` and run
  `make check`.
- `make lint` validates frontmatter, path layout, and reference links, and warns
  when a description lacks trigger language.
- `make index` regenerates the README skill table. Never hand-edit between the
  `SKILLS-INDEX` markers.
- `make check` runs lint plus `build_index.py --check` and is the gate before
  every commit. CI (`.github/workflows/validate.yml`) runs the same, so a stale
  index or a lint failure fails the build.

## Authoring with skill-creator
Use the `skill-creator` skill to scaffold, evaluate, and optimize skills. It ships
the full toolkit: a validator, a packager that produces `.skill` files, a
description optimizer that splits train/test and fixes under-triggering against
held-out cases, and an eval/benchmark harness. Put per-skill cases in
`evals/evals.json`. Optimize the description until it triggers reliably, not just
until it reads well.
