# Evals for the agent's configuration

A change to `CLAUDE.md`, `REVIEW.md`, a hook or a skill can make the agent
worse. This suite catches that the way tests catch a code regression.

- Each file in `cases/` is one real past ticket: the prompt the agent got and
  the checks that define an acceptable result.
- Aim for 20 to 50 cases. Add one for every defect that reaches the default branch.
- `run.sh` validates the cases today. Running them against a coding agent is
  not wired up yet; that needs an API key and a budget.
- A configuration change that lowers the pass rate does not merge until the
  configuration's owner has reviewed it.

## Case format

| Field | Meaning |
| --- | --- |
| `id` | Short, stable name |
| `ticket` | The ticket the case came from |
| `prompt` | What the agent is asked to do |
| `checks` | Commands that must exit 0 for the case to pass |
| `allowed_tools` | Tools the agent may use for this case |
