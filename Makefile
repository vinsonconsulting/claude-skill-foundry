.PHONY: lint index check

lint:
	python3 scripts/lint_skills.py

index:
	python3 scripts/build_index.py

check:
	python3 scripts/lint_skills.py && python3 scripts/build_index.py --check
