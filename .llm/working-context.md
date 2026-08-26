# Working Context

## Current state

This repository holds Ray's shell, Git, terminal, direnv, and workstation
configuration. The current architecture separates shared startup behavior from
Windows Git Bash and Ubuntu/WSL behavior.

Recent work completed the cross-platform Bash split, Windows Terminal project
profiles, Git ignore policy cleanup, and project-browser handoffs.

## Next

Use this repository to support the gradual migration of everyday development
from Windows Git Bash to Ubuntu under WSL2. Keep Windows as the desktop host,
but prefer Linux Git, Java, Gradle, Python, and Node for normal project work.

For Markdown organization, keep human-facing documentation in the root or
`docs/`, and keep LLM working state under `.llm/`.

## Open questions

- Whether the old Ubuntu 22.04 WSL distro should be removed.
- Whether browser project workspaces need automation beyond `project-home.html`.
- Which project should be the next concrete WSL migration test.

## Deferred

- Further `bin` versus `dotfiles/bin` cleanup.
- Broader shell style cleanup unless it blocks WSL migration.
