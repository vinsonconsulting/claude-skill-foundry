# Contributing

Low on ceremony, high on the description field. That field is what makes a skill
findable by a model, so it earns the most attention.

## A skill is a folder

```
skills/<category>/<skill-name>/
  SKILL.md            # required: frontmatter + instructions
  reference/          # optional: docs the skill points to
  scripts/            # optional: helper scripts the skill runs
  assets/             # optional: templates, samples
```

## SKILL.md frontmatter

```yaml
---
name: your-skill-name
description: One or two sentences on what this does and, more importantly, when
  to use it. This is the text a model matches against, so name concrete triggers.
---
```

Everything after the frontmatter is the instructions: how to do the thing, what
to read, what to produce.

## Before you commit

- `make check` passes (lint clean, index regenerated)
- `name` matches the folder name
- No secrets. Reference `.env`, a secrets manager, or 1Password instead of
  pasting keys.

## Linting

`make lint` is the baseline. Run `python3 scripts/lint_skills.py --strict` to
treat warnings as errors. Tune the rules in `scripts/lint_skills.py` to fit how
you write skills.
