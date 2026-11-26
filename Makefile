# Local entry points. CI does not call make: .github/workflows/ci.yml holds
# the real steps, and `make ci` repeats them so that they can run before a
# push. scripts/check-ci-mirror.sh fails when the two drift apart.
#
# The hooks and the agent call verify, ci and fmt, so keep those names.
# Every target must exit non-zero on failure.

.PHONY: verify ci fmt setup check deploy-ephemeral smoke destroy-ephemeral

# The fast part of the project's checks. The agent runs it before it reports
# a task done.
verify:
	uv run --locked ruff format --check .
	uv run --locked ruff check .
	uv run --locked python scripts/check-architecture.py
	uv run --locked mypy
	uv run --locked coverage run -m pytest
	uv run --locked coverage report
	uv run --locked coverage report --include='core/*' --fail-under=100

# Everything CI runs that can run locally: the same commands as the gates and
# checks jobs. The pre-push hook runs it.
ci:
	./scripts/check-template-configured.sh
	./scripts/check-classified.sh
	./scripts/check-codeowners.sh
	./scripts/check-ci-mirror.sh
	./scripts/check-implemented-rules.sh
	./scripts/tests/run.sh
	uv sync --locked
	uv run --locked ruff format --check .
	uv run --locked ruff check .
	uv run --locked python scripts/check-architecture.py
	uv run --locked mypy
	uv run --locked coverage run -m pytest
	uv run --locked coverage report
	uv run --locked coverage report --include='core/*' --fail-under=100
	uv run --locked pip-audit

# Formats one file: make fmt FILE=path/to/file
# The hook calls it for every file the agent edits, so anything but Python is left alone.
fmt:
	@case "$(FILE)" in *.py) uv run --locked ruff format "$(FILE)" ;; esac

# Once per clone: makes git run the hooks in .githooks/.
setup:
	git config core.hooksPath .githooks

# Self-tests for the hooks and gate scripts in this repo.
check:
	@./scripts/tests/run.sh

# --- Deployed check (see .github/workflows/deployed-check.yml) ---------------
# Switched off until these three run real commands.

# Deploys this build to a throwaway environment with the real deployment script.
deploy-ephemeral:
	@echo "The deployed check is not set up: no deploy-ephemeral command." >&2; exit 1

# Scripted smoke tests against the throwaway environment.
smoke:
	@echo "The deployed check is not set up: no smoke command." >&2; exit 1

destroy-ephemeral:
	@echo "The deployed check is not set up: no destroy-ephemeral command." >&2; exit 1
