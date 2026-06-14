#!/usr/bin/env bash
set -euo pipefail

# new-skill.sh — scaffold a new skill from skills/_TEMPLATE.
# Usage: tools/new-skill.sh <category> <name>
# The description is left as a placeholder on purpose: it's the highest-leverage
# field and decides whether the skill ever fires, so write it by hand.

usage() {
  cat >&2 <<USAGE
Usage: $(basename "$0") <category> <name>
  <category>  lowercase slug, e.g. dev, writing, clients, infra
  <name>      lowercase slug, e.g. astro-cf-migrate
USAGE
  exit 2
}

[ "$#" -eq 2 ] || usage
category="$1"; name="$2"

slug='^[a-z0-9]+(-[a-z0-9]+)*$'
[[ "$category" =~ $slug ]] || { echo "error: category must be a lowercase slug" >&2; exit 1; }
[[ "$name" =~ $slug ]]     || { echo "error: name must be a lowercase slug" >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
template="$repo_root/skills/_TEMPLATE"
dest="$repo_root/skills/$category/$name"

[ -d "$template" ] || { echo "error: template not found at $template" >&2; exit 1; }
[ -e "$dest" ]     && { echo "error: $dest already exists" >&2; exit 1; }

mkdir -p "$(dirname "$dest")"
cp -R "$template" "$dest"

skill_md="$dest/SKILL.md"
if [ -f "$skill_md" ]; then
  tmp="$(mktemp)"
  sed -e "s/^name:.*/name: $name/" -e "s/^# Replace with skill name.*/# $name/" "$skill_md" > "$tmp" && mv "$tmp" "$skill_md"
fi

evals="$dest/evals/evals.json"
if [ -f "$evals" ]; then
  tmp="$(mktemp)"
  sed -e "s/\"skill_name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"skill_name\": \"$name\"/" "$evals" > "$tmp" && mv "$tmp" "$evals"
fi

cat <<DONE
Created skills/$category/$name
Next:
  1. Write the description in $skill_md (concrete triggers, slightly pushy; it decides whether the skill fires).
  2. Fill the body: imperative, under ~500 lines, push detail into references/.
  3. Add eval cases in evals/evals.json for verifiable skills, then run: make check
DONE
