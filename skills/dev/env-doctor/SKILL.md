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
