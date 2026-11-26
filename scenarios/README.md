# Scenarios

A scenario is a short story of use, written from the project specification:
what someone does with the system, and what they must then observe. The
deployed check plays the scenarios against a real deployment of each PR.

## Who writes them

The specification owner, with `/hl:write-scenarios`. The agent that writes
them is given the specification and nothing else, so a scenario says what the
specification asks for and not what the code happens to do.

They are not the coding agent's to change. This folder is a critical path:
every change needs a code owner's approval. If a scenario looks wrong while
you work on a ticket, stop and tell the person you work for.

## Layout

One folder per chapter of the specification, `<chapter number>-<name>/`, with
one file per scenario:

```markdown
---
id: GV1-SC-07-01
chapter: 7
rules: [GV1-KEY-07, GV1-AUT-04]
roles: [owner, co-signer]
---
# One signature is never enough

## Setup

A guarded Safe with keys P and H set.

## Steps

1. The owner submits a transfer signed with P only.

## Expected

- The transaction is refused.
- No balance changes.
```

## Which scenarios run

A scenario can only be played once the rules it names are built. The file
`rules-implemented.txt` at the top of the repository lists the rules this
branch's code implements, one ID per line. `/hl:open-pr` adds a ticket's rules
to it.

`scripts/scenarios-runnable.sh` prints the scenarios whose rules are all on
that list, and says for every other scenario which rules it still waits for.
So a scenario runs for the first time on the PR that builds the last of its
rules.

A rule leaves the list in one case: its requirement changed. The change that
updates its scenarios takes it off the list, and the story that builds the
rule again puts it back.
