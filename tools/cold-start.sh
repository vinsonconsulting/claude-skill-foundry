#!/usr/bin/env bash
#
# cold-start.sh
# Bootstrap two skills monorepos from nothing:
#   - public  : Jim's Filing Cabinet of Claude Skills
#   - private : Jim's Secret Cabinet of Mysteries
#
# Each repo gets identical tooling (frontmatter linter, README index generator,
# CI, Makefile, skill template) and visibility-appropriate docs/license. The
# script writes everything, self-verifies (lint + index --check), and optionally
# inits git and pushes via the gh CLI.
#
# Usage:
#   ./cold-start.sh [--dest DIR] [--owner NAME] [--force]
#                   [--no-git] [--push] [--no-public] [--no-private]
#
# Flags:
#   --dest DIR     Parent directory to create the cabinets in (default: .)
#   --owner NAME   GitHub owner for badge URLs and remotes (default below)
#   --force        Overwrite target directories if they already exist
#   --no-git       Skip git init + first commit
#   --push         Create the repos with gh and push (implies git; needs gh auth)
#   --no-public    Skip building the public cabinet
#   --no-private   Skip building the private cabinet
#   -h, --help     Show this help
#
# Requirements: bash, python3, perl (all stock on macOS). git only if committing,
# gh only if --push.

set -euo pipefail

# ----------------------------- config (edit me) -----------------------------
PUBLIC_DISPLAY="Jim's Filing Cabinet of Claude Skills"
PUBLIC_SLUG="jims-filing-cabinet-of-claude-skills"

PRIVATE_DISPLAY="Jim's Secret Cabinet of Mysteries"
PRIVATE_SLUG="jims-secret-cabinet-of-mysteries"

OWNER="vinsonconsulting"
HOLDER="Vinson Consulting"
YEAR="2026"
PY="python3"
# ---------------------------------------------------------------------------

DEST="."
FORCE="0"
DO_GIT="1"
DO_PUSH="0"
DO_PUBLIC="1"
DO_PRIVATE="1"

# set per-repo before scaffolding; consumed by subst()
PROJECT_DISPLAY=""
REPO_SLUG=""

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32mok\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)       DEST="${2:?--dest needs a value}"; shift 2 ;;
    --owner)      OWNER="${2:?--owner needs a value}"; shift 2 ;;
    --force)      FORCE="1"; shift ;;
    --no-git)     DO_GIT="0"; shift ;;
    --push)       DO_PUSH="1"; shift ;;
    --no-public)  DO_PUBLIC="0"; shift ;;
    --no-private) DO_PRIVATE="0"; shift ;;
    -h|--help)    usage ;;
    *)            die "unknown flag: $1 (try --help)" ;;
  esac
done

command -v "$PY" >/dev/null 2>&1 || die "$PY not found; install Python 3"
command -v perl  >/dev/null 2>&1 || die "perl not found"
if [ "$DO_PUSH" = "1" ]; then
  DO_GIT="1"
  command -v gh >/dev/null 2>&1 || die "--push needs the gh CLI, which is not installed"
fi

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

# replace __PLACEHOLDER__ tokens in a file using current globals (injection-safe)
subst() {
  PROJECT_DISPLAY="$PROJECT_DISPLAY" REPO_SLUG="$REPO_SLUG" OWNER="$OWNER" \
  HOLDER="$HOLDER" YEAR="$YEAR" perl -0777 -pi -e '
    s/__PROJECT_DISPLAY__/$ENV{PROJECT_DISPLAY}/g;
    s/__REPO_SLUG__/$ENV{REPO_SLUG}/g;
    s/__OWNER__/$ENV{OWNER}/g;
    s/__HOLDER__/$ENV{HOLDER}/g;
    s/__YEAR__/$ENV{YEAR}/g;
  ' "$1"
}

prepare_target() {
  local d="$1"
  if [ -e "$d" ]; then
    if [ "$FORCE" = "1" ]; then
      info "overwriting existing $d"
      rm -rf "$d"
    else
      die "$d already exists (use --force to overwrite)"
    fi
  fi
  mkdir -p "$d"
}

emit_make() {
  local mk="$1/Makefile"
  printf '.PHONY: lint index check\n\n'                                            >  "$mk"
  printf 'lint:\n\t%s scripts/lint_skills.py\n\n' "$PY"                            >> "$mk"
  printf 'index:\n\t%s scripts/build_index.py\n\n' "$PY"                           >> "$mk"
  printf 'check:\n\t%s scripts/lint_skills.py && %s scripts/build_index.py --check\n' "$PY" "$PY" >> "$mk"
}

emit_scripts() {
  local d="$1"
  mkdir -p "$d/scripts"

  cat > "$d/scripts/skilltools.py" <<'SKILLTOOLS'
#!/usr/bin/env python3
"""Shared helpers for the skills tooling.

Dependency-free (stdlib only). The frontmatter parser handles the shapes used in
SKILL.md frontmatter: single-line `key: value`, quoted values, YAML plain
multi-line scalars (wrapped/indented continuation lines), and folded (`>`) or
literal (`|`) block scalars. It is not a full YAML implementation.
"""
from __future__ import annotations
from pathlib import Path


def _strip_quotes(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] in "\"'" and v[-1] == v[0]:
        return v[1:-1]
    return v


def parse_frontmatter(text: str) -> dict:
    """Pull top-level scalar keys from a leading --- frontmatter block."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    fm: dict[str, str] = {}
    i = 1
    cur_key = None
    block = None               # 'folded' | 'literal'
    block_lines: list[str] = []
    block_indent = None
    last_key = None

    def flush_block():
        nonlocal block, block_lines, block_indent, cur_key
        if block is not None and cur_key is not None:
            joiner = " " if block == "folded" else "\n"
            fm[cur_key] = joiner.join(block_lines).strip()
        block = None
        block_lines = []
        block_indent = None

    while i < len(lines):
        line = lines[i]
        if block is not None:
            if line.strip() == "" or line.startswith((" ", "\t")):
                if line.strip() == "":
                    block_lines.append("")
                else:
                    if block_indent is None:
                        block_indent = len(line) - len(line.lstrip())
                    block_lines.append(line[block_indent:])
                i += 1
                continue
            flush_block()

        stripped = line.strip()
        if stripped == "---":
            break
        if not stripped:
            i += 1
            continue

        indented = line.startswith((" ", "\t"))
        if not indented and ":" in line and not stripped.startswith("#"):
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            if val in (">", ">-", "|", "|-"):
                cur_key = key
                block = "folded" if val.startswith(">") else "literal"
                block_lines = []
                block_indent = None
                last_key = None
            else:
                fm[key] = _strip_quotes(val)
                last_key = key
            i += 1
            continue

        if indented and last_key is not None and not stripped.startswith("#"):
            sep = " " if fm.get(last_key) else ""
            fm[last_key] = (fm.get(last_key, "") + sep + stripped).strip()
            i += 1
            continue

        i += 1

    flush_block()
    return fm


def iter_skill_files(skills_dir: Path) -> list[Path]:
    """All SKILL.md under skills_dir, skipping meta/hidden paths.

    Any path component starting with '_' or '.' is ignored, so folders like
    `_TEMPLATE` and dotfiles never count as skills.
    """
    if not skills_dir.is_dir():
        return []
    out: list[Path] = []
    for p in sorted(skills_dir.rglob("SKILL.md")):
        rel_parts = p.relative_to(skills_dir).parts
        if any(part.startswith(("_", ".")) for part in rel_parts):
            continue
        out.append(p)
    return out
SKILLTOOLS

  cat > "$d/scripts/lint_skills.py" <<'LINT'
#!/usr/bin/env python3
"""Validate every SKILL.md under skills/.

Baseline checks (tune to taste in this file):
  ERROR  missing frontmatter block
  ERROR  missing or empty `name`
  ERROR  missing or empty `description`
  WARN   `name` is not a lowercase slug
  WARN   `name` does not match the skill folder name (skipped for namespaced a:b)
  WARN   description longer than DESCRIPTION_MAX chars
  WARN   a relative file referenced in the body does not exist

Exit code: 1 if any ERROR, or any WARN when run with --strict. Otherwise 0.

Usage:
  python3 scripts/lint_skills.py
  python3 scripts/lint_skills.py --strict
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

from skilltools import parse_frontmatter, iter_skill_files

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"

DESCRIPTION_MAX = 1024
NAME_RE = re.compile(
    r"^[a-z0-9]+(?:[-_][a-z0-9]+)*(?::[a-z0-9]+(?:[-_][a-z0-9]+)*)?$"
)
REF_RE = re.compile(
    r"(?:\]\(|`)((?:scripts|reference|references|assets|data)/[^)\s`]+)"
)
TRIGGER_RE = re.compile(
    r"\b(use\s+(this\s+|the\s+)?(skill\s+)?(when|for)|whenever|when\s+the\s+user|when\s+you\s+need|trigger)\b",
    re.IGNORECASE,
)


def lint_skill(path: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warns: list[str] = []
    text = path.read_text(encoding="utf-8")
    has_fm = text.lstrip().startswith("---")
    fm = parse_frontmatter(text)

    if not has_fm:
        errors.append("missing YAML frontmatter (--- block)")
    name = (fm.get("name") or "").strip()
    desc = (fm.get("description") or "").strip()
    if not name:
        errors.append("missing or empty `name`")
    if not desc:
        errors.append("missing or empty `description`")
    if name and not NAME_RE.match(name):
        warns.append(f"`name` is not a lowercase slug: {name!r}")
    folder = path.parent.name
    if name and ":" not in name and name != folder:
        warns.append(f"`name` ({name!r}) does not match folder ({folder!r})")
    if desc and len(desc) > DESCRIPTION_MAX:
        warns.append(f"description is {len(desc)} chars (> {DESCRIPTION_MAX})")
    if desc and not TRIGGER_RE.search(desc):
        warns.append("description may lack explicit trigger language (e.g. \"Use when ...\")")

    body = text.split("---", 2)[-1] if has_fm else text
    for m in REF_RE.finditer(body):
        ref = m.group(1)
        if not (path.parent / ref).exists():
            warns.append(f"referenced file not found: {ref}")
    return errors, warns


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    files = iter_skill_files(SKILLS_DIR)
    if not files:
        print("No skills found under skills/. Nothing to lint.")
        return 0

    total_err = 0
    total_warn = 0
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        errors, warns = lint_skill(path)
        total_err += len(errors)
        total_warn += len(warns)
        if not errors and not warns:
            print(f"[ok]   {rel}")
            continue
        tag = "[FAIL]" if errors else "[warn]"
        print(f"{tag} {rel}")
        for e in errors:
            print(f"         error: {e}")
        for w in warns:
            print(f"         warn:  {w}")

    print(
        f"\n{len(files)} skill(s) checked, "
        f"{total_err} error(s), {total_warn} warning(s)."
    )
    if total_err or (strict and total_warn):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
LINT

  cat > "$d/scripts/build_index.py" <<'BUILDINDEX'
#!/usr/bin/env python3
"""Generate the skills index and inject it into README.md.

Walks skills/ for SKILL.md files, reads `name` and `description` from the
frontmatter, and writes a Markdown table grouped by top-level category between
the SKILLS-INDEX markers in README.md.

Usage:
  python3 scripts/build_index.py            # write the index into README.md
  python3 scripts/build_index.py --check    # exit 1 if README.md is out of date
"""
from __future__ import annotations
import sys
from pathlib import Path

from skilltools import parse_frontmatter, iter_skill_files

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
README = ROOT / "README.md"
START = "<!-- SKILLS-INDEX:START -->"
END = "<!-- SKILLS-INDEX:END -->"


def discover() -> list[tuple[str, str, str, str]]:
    records = []
    for p in iter_skill_files(SKILLS_DIR):
        fm = parse_frontmatter(p.read_text(encoding="utf-8"))
        name = (fm.get("name") or p.parent.name).strip()
        desc = (fm.get("description") or "").strip()
        rel = p.relative_to(SKILLS_DIR).parts
        category = rel[0] if len(rel) >= 3 else "uncategorized"
        path_display = p.parent.relative_to(ROOT).as_posix()
        records.append((category, name, desc, path_display))
    return records


def render_index() -> str:
    rows = discover()
    if not rows:
        return "_No skills yet. Add one under `skills/<category>/<name>/SKILL.md`._"
    by_cat: dict[str, list[tuple[str, str, str]]] = {}
    for category, name, desc, path in rows:
        by_cat.setdefault(category, []).append((name, desc, path))
    out: list[str] = []
    for category in sorted(by_cat):
        out.append(f"### {category}\n")
        out.append("| Skill | Description | Path |")
        out.append("| --- | --- | --- |")
        for name, desc, path in sorted(by_cat[category]):
            d = desc.replace("|", "\\|").replace("\n", " ")
            out.append(f"| `{name}` | {d} | `{path}/` |")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def inject(readme_text: str, index_md: str) -> str:
    if START not in readme_text or END not in readme_text:
        raise SystemExit(
            "README.md is missing the index markers. Add these two lines "
            f"where the index should go:\n  {START}\n  {END}"
        )
    pre = readme_text.split(START)[0]
    post = readme_text.split(END, 1)[1]
    return f"{pre}{START}\n\n{index_md}\n{END}{post}"


def main(argv: list[str]) -> int:
    check = "--check" in argv
    index_md = render_index()
    current = README.read_text(encoding="utf-8") if README.exists() else ""
    updated = inject(current, index_md)
    if check:
        if updated != current:
            print("README.md skills index is out of date. Run: make index")
            return 1
        print("Skills index is up to date.")
        return 0
    README.write_text(updated, encoding="utf-8")
    print("Updated README.md skills index.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
BUILDINDEX

  emit_make "$d"
}

emit_common_meta() {
  local d="$1"
  mkdir -p "$d/.github/workflows" "$d/skills/_TEMPLATE" "$d/skills/_TEMPLATE/evals"

  cat > "$d/.gitignore" <<'GITIGNORE'
.DS_Store
__pycache__/
*.pyc
.venv/
venv/
.env
.env.*
*.bak
.idea/
.vscode/
.obsidian/
GITIGNORE

  cat > "$d/.github/workflows/validate.yml" <<'WORKFLOW'
name: validate

on:
  push:
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Lint skills
        run: python3 scripts/lint_skills.py
      - name: Check index is current
        run: python3 scripts/build_index.py --check
WORKFLOW

  cat > "$d/skills/_TEMPLATE/SKILL.md" <<'TEMPLATE'
---
name: replace-with-skill-name
description: Replace this. One or two sentences on what the skill does and the
  situations that should trigger it. This text is matched by a model, so name
  concrete triggers, not vague capabilities.
---

<!-- Optional sibling dirs: scripts/ (helpers), references/ (on-demand docs), assets/ (output files), evals/ (test cases). Remove this line. -->

# Replace with skill name

Short statement of what running this skill accomplishes.

## Process

1. Step one.
2. Step two.

## Output

What the skill should produce.
TEMPLATE

  cat > "$d/skills/_TEMPLATE/evals/evals.json" <<'EVALS'
{
  "skill_name": "replace-with-skill-name",
  "evals": [
    {
      "id": 1,
      "prompt": "A realistic prompt a user would actually type that should trigger this skill.",
      "expected_output": "What a good result looks like.",
      "files": []
    }
  ]
}
EVALS
}

build_public() {
  local d="$DEST/$PUBLIC_SLUG"
  PROJECT_DISPLAY="$PUBLIC_DISPLAY"
  REPO_SLUG="$PUBLIC_SLUG"
  info "building public: $PROJECT_DISPLAY -> $d"
  prepare_target "$d"
  emit_scripts "$d"
  emit_common_meta "$d"

  mkdir -p "$d/skills/writing/plain-language-edit/reference" \
           "$d/skills/dev/env-doctor"

  cat > "$d/LICENSE" <<'LICENSE'
MIT License

Copyright (c) __YEAR__ __HOLDER__

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE

  cat > "$d/README.md" <<'README'
# __PROJECT_DISPLAY__

A filing cabinet for skills: small, self-contained capability folders that an LLM
(Claude in particular) loads on demand. Each skill is a directory under `skills/`
with a `SKILL.md` and whatever scripts, references, or assets it needs.

Built to be Claude-optimized and plainly usable anywhere. Clone the repo, copy the
folder you want, done.

[![validate](https://github.com/__OWNER__/__REPO_SLUG__/actions/workflows/validate.yml/badge.svg)](https://github.com/__OWNER__/__REPO_SLUG__/actions/workflows/validate.yml)
![license](https://img.shields.io/badge/license-MIT-blue)

## Layout

```
skills/<category>/<skill-name>/SKILL.md
```

`SKILL.md` carries YAML frontmatter with a `name` and a `description`. The
description is what a model reads to decide whether to load the skill, so keep it
specific about when to use it, not just what it does.

## Skills

<!-- SKILLS-INDEX:START -->
<!-- SKILLS-INDEX:END -->

## Add a skill

1. Copy the template: `cp -r skills/_TEMPLATE skills/<category>/<your-skill>`
2. Edit `SKILL.md`. Set `name` to match the folder, write a description that says
   when to use it.
3. Add supporting files in the skill folder (`scripts/`, `reference/`, `assets/`).
4. Regenerate the index and lint: `make check`.
5. Commit. CI runs the same checks.

## Commands

| Command | What it does |
| --- | --- |
| `make lint` | Validate every `SKILL.md` |
| `make index` | Rewrite the Skills table above |
| `make check` | Lint, then verify the index is current (what CI runs) |

## Conventions

Folder names and skill `name` values are lowercase slugs. Anything under `skills/`
whose name starts with `_` (like `_TEMPLATE`) is ignored by the tooling. No secrets
in any skill: reference where they live instead.

## License

MIT. See [LICENSE](LICENSE).
README

  cat > "$d/CONTRIBUTING.md" <<'CONTRIB'
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
CONTRIB

  cat > "$d/CLAUDE.md" <<'CLAUDEMD'
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
CLAUDEMD

  cat > "$d/skills/writing/plain-language-edit/SKILL.md" <<'SKILL_PLE'
---
name: plain-language-edit
description: Rewrite dense, jargon-heavy, or bureaucratic text into plain language
  without losing meaning. Use when a user asks to simplify, de-jargon, or make
  writing clearer and more direct, or when prose reads like corporate boilerplate.
---

# Plain language edit

Rewrite the supplied text so a non-specialist reads it once and gets it.

## Process

1. Identify the audience and the single thing the text needs to convey.
2. Cut filler openers and hedges. Replace abstract nouns with verbs.
3. Swap inflated words for ordinary ones. See `reference/word-swaps.md`.
4. Break long sentences. One idea per sentence where it helps.
5. Preserve meaning and any required caveats. Do not oversimplify legal or
   safety-critical content.

## Output

Return the rewritten text only, unless the user asks for an explanation of the
changes.
SKILL_PLE

  cat > "$d/skills/writing/plain-language-edit/reference/word-swaps.md" <<'WORDSWAPS'
# Common word swaps

| Inflated | Plain |
| --- | --- |
| utilize | use |
| facilitate | help |
| in order to | to |
| at this point in time | now |
| commence | start |
| terminate | end |
| in the event that | if |
| with regard to | about |
WORDSWAPS

  cat > "$d/skills/dev/env-doctor/SKILL.md" <<'SKILL_ENV'
---
name: env-doctor
description: Diagnose a broken local development environment by checking language
  runtimes, package managers, environment variables, and common path or version
  mismatches. Use when a project will not build, run, or install dependencies and
  the cause is unclear.
---

# Env doctor

Work from the outside in. Confirm the basics before chasing exotic causes.

## Checklist

1. Runtime present and the version the project expects (check the lockfile or
   config).
2. Package manager installed and able to reach its registry.
3. Required environment variables set. Never print secret values; confirm
   presence only.
4. PATH ordering: the expected binary resolves to the expected location.
5. Clean reinstall as a last resort, after the above are ruled out.

## Output

Report what was checked, what failed, and the single most likely fix first.
SKILL_ENV

  subst "$d/README.md"
  subst "$d/LICENSE"
  subst "$d/CLAUDE.md"

  ( cd "$d" && "$PY" scripts/lint_skills.py && "$PY" scripts/build_index.py && "$PY" scripts/build_index.py --check ) \
    || die "verification failed in $d"
  ok "public cabinet verified"

  finalize_repo "$d" "Filing cabinet: skills tooling, CI, templates, sample skills" "--public"
}

build_private() {
  local d="$DEST/$PRIVATE_SLUG"
  PROJECT_DISPLAY="$PRIVATE_DISPLAY"
  REPO_SLUG="$PRIVATE_SLUG"
  info "building private: $PROJECT_DISPLAY -> $d"
  prepare_target "$d"
  emit_scripts "$d"
  emit_common_meta "$d"

  mkdir -p "$d/skills/clients/deliverable-formatter"

  cat > "$d/NOTICE.md" <<'NOTICE'
# Notice

Copyright (c) __YEAR__ __HOLDER__. All rights reserved.

This repository and its contents are proprietary and confidential. It holds
client-confidential and internal material. No license is granted to use, copy,
modify, or distribute any part of it. Do not publish or share it outside the
authorized scope.

## No secrets

Secrets do not belong in this repository even though it is private. Reference
where a credential lives (environment file, secrets manager, 1Password); never
commit the value.
NOTICE

  cat > "$d/README.md" <<'README'
# __PROJECT_DISPLAY__

The locked drawer. Client-confidential and internal-only skills, same structure
and tooling as the public cabinet, kept separate so visibility differs on the
right side of the no-share line.

> Private and confidential. Do not publish, mirror, or copy skills out of this
> repo without sign-off.

## Layout

```
skills/<category>/<skill-name>/SKILL.md
```

## Skills

<!-- SKILLS-INDEX:START -->
<!-- SKILLS-INDEX:END -->

## Add a skill

1. `cp -r skills/_TEMPLATE skills/<category>/<your-skill>`
2. Edit `SKILL.md`. `name` matches the folder; description says when to use it.
3. Add supporting files as needed.
4. `make check`, then commit.

## Commands

| Command | What it does |
| --- | --- |
| `make lint` | Validate every `SKILL.md` |
| `make index` | Rewrite the Skills table above |
| `make check` | Lint, then verify the index is current |

## Hard rule: no secrets

Client work lives here, which makes the no-secrets rule non-negotiable. No API
keys, tokens, passwords, or client PII in any skill or commit. Reference where the
secret lives (`.env`, Cloudflare Secrets, 1Password). A skill that needs a
credential names it; it never contains it.

## License

Proprietary. See [NOTICE.md](NOTICE.md).
README

  cat > "$d/CONTRIBUTING.md" <<'CONTRIB'
# Contributing (internal)

Same mechanics as the public library. The difference is what is allowed to leave.

## A skill is a folder

```
skills/<category>/<skill-name>/
  SKILL.md
  reference/   scripts/   assets/   (optional)
```

## Rules

- `make check` passes before commit.
- `name` matches the folder name.
- No secrets, ever. Reference where they live.
- No client PII beyond what the skill genuinely needs.
- Confidential by default. Do not copy a skill into the public repo without
  sign-off; some are client-specific and stay here.
CONTRIB

  cat > "$d/CLAUDE.md" <<'CLAUDEMD'
# CLAUDE.md

Private skills monorepo. Client-confidential and internal-only. Same mechanics as
the public cabinet.

## Working here

- Add a skill: `cp -r skills/_TEMPLATE skills/<category>/<name>`, edit
  `SKILL.md`, run `make check`.
- `make lint` validates; `make index` regenerates the README table (don't
  hand-edit between the markers).
- Folders under `skills/` starting with `_` are ignored.

## Non-negotiable

- No secrets, ever, even though the repo is private. Reference where they live
  (`.env`, Cloudflare Secrets, 1Password).
- No client PII beyond what a skill genuinely needs.
- Confidential by default. Do not copy a skill to the public cabinet without
  sign-off.
CLAUDEMD

  cat > "$d/skills/clients/deliverable-formatter/SKILL.md" <<'SKILL_DF'
---
name: deliverable-formatter
description: Format a finished work product into the standard client deliverable
  layout (cover, summary, body, appendix) with consistent headings and naming.
  Use when packaging completed work for client handoff. This is a structural
  sample with no client data; replace or delete it.
---

# Deliverable formatter

Turn a finished draft into the standard handoff package.

## Process

1. Confirm the client and deliverable type to select the right layout.
2. Apply the standard section order: cover, summary, body, appendix.
3. Normalize headings, numbering, and file naming to the house convention.
4. Flag anything confidential that should not leave in this version.

## Output

A formatted deliverable plus a one-line manifest of what is included.

## Note

Sample skill. Contains no client-specific content. Replace with real skills or
delete.
SKILL_DF

  subst "$d/README.md"
  subst "$d/NOTICE.md"
  subst "$d/CLAUDE.md"

  ( cd "$d" && "$PY" scripts/lint_skills.py && "$PY" scripts/build_index.py && "$PY" scripts/build_index.py --check ) \
    || die "verification failed in $d"
  ok "private cabinet verified"

  finalize_repo "$d" "Secret cabinet: skills tooling, CI, templates, sample skill" "--private"
}

finalize_repo() {
  local d="$1" msg="$2" vis="$3"
  [ "$DO_GIT" = "1" ] || { info "skipping git ($d)"; return 0; }

  ( cd "$d" && git init -b main -q && git add . && git commit -qm "$msg" )
  ok "git initialized and committed ($d)"

  if [ "$DO_PUSH" = "1" ]; then
    info "creating $OWNER/$REPO_SLUG on GitHub ($vis) and pushing"
    ( cd "$d" && gh repo create "$OWNER/$REPO_SLUG" --source=. --remote=origin --push "$vis" )
    ok "pushed ($d)"
  fi
}

# --------------------------------- run ------------------------------------
info "destination: $DEST   owner: $OWNER"
[ "$DO_PUBLIC"  = "1" ] && build_public
[ "$DO_PRIVATE" = "1" ] && build_private

echo
ok "done."
[ "$DO_PUBLIC"  = "1" ] && echo "  public : $DEST/$PUBLIC_SLUG"
[ "$DO_PRIVATE" = "1" ] && echo "  private: $DEST/$PRIVATE_SLUG"
if [ "$DO_GIT" = "1" ] && [ "$DO_PUSH" = "0" ]; then
  echo
  echo "Next: create the repos and push (swap owner if needed)."
  [ "$DO_PUBLIC"  = "1" ] && echo "  (cd $DEST/$PUBLIC_SLUG  && gh repo create $OWNER/$PUBLIC_SLUG  --source=. --remote=origin --push --public)"
  [ "$DO_PRIVATE" = "1" ] && echo "  (cd $DEST/$PRIVATE_SLUG && gh repo create $OWNER/$PRIVATE_SLUG --source=. --remote=origin --push --private)"
  echo "Or rerun with --push to do it now."
fi
