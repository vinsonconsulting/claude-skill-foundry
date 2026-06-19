.PHONY: lint index check tools cards

# Every real skill: a SKILL.md, minus the template and any vendored mirror.
SKILL_DIRS := $(shell find skills -name SKILL.md -not -path '*/_TEMPLATE/*' -not -path '*/vendor/*' -exec dirname {} \;)
# Gate input (scan.json) is written here, OUTSIDE the skill dirs, so SkillSpector
# never re-scans its own output on the next run. Gitignored.
SCAN_DIR := .skillcheck

lint:
	python3 scripts/lint_skills.py

index:
	python3 scripts/build_index.py

# Install the vendored Califa tooling (skillcard) + SkillSpector into the active
# environment. Run once before `make check`; CI runs it as its own step.
tools:
	python3 -m pip install -e "tooling/califa[scan]"

# Scan every skill with SkillSpector, gate the JSON report, and validate its card.
# Policy (Califa SPEC.md §E): HIGH/CRITICAL (or any CRITICAL-severity finding)
# always fails; a carded skill must accept+note every MEDIUM finding; an
# un-carded MEDIUM is a warning, not a failure, while the library is carded up.
# We strip generated artifacts before scanning so they never self-pollute the
# results; scan.json goes to $(SCAN_DIR), report.sarif (committed, deterministic)
# is regenerated from a clean dir.
cards:
	@set -e; mkdir -p $(SCAN_DIR); for d in $(SKILL_DIRS); do \
		echo ">> $$d"; \
		key=$$(echo "$$d" | tr '/' '_'); \
		rm -f "$$d/scan.json" "$$d/report.sarif"; \
		skillspector scan "$$d" --no-llm --format json --output "$(SCAN_DIR)/$$key.json"; \
		if [ -f "$$d/skill-card.md" ]; then \
			skillspector scan "$$d" --no-llm --format sarif --output "$$d/report.sarif"; \
			python3 -m skillcard.cli gate "$(SCAN_DIR)/$$key.json" --card "$$d/skill-card.md"; \
			python3 -m skillcard.cli validate "$$d"; \
		else \
			python3 -m skillcard.cli gate "$(SCAN_DIR)/$$key.json" --warn-medium-without-card; \
		fi; \
	done

check: lint cards
	python3 scripts/build_index.py --check
