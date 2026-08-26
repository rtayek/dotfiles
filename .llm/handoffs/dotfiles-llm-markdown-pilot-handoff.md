# Handoff: Pilot the LLM Markdown Convention on the Dotfiles Project

## Goal

Pilot the proposed Markdown/LLM project-file convention on the **dotfiles** repository.

Do **not** use the `.MD Files` project as the pilot. That project is intended to define and preserve reusable project templates and conventions. The dotfiles repository is a better real-world test case because it is an active project with actual agent instructions, handoffs, working notes, documentation, scripts, and ongoing work.

The purpose of this pilot is to learn what structure is genuinely useful before standardizing it across other repositories.

## Proposed structure

Use this as the starting model, not as an inflexible requirement:

```text
project/
|-- README.md
|-- AGENTS.md
|-- CLAUDE.md
|
|-- docs/
|   |-- architecture.md
|   |-- design.md
|   `-- other durable project documentation
|
`-- .llm/
    |-- HUMAN.md
    |-- PERSONA.md
    |-- working-context.md
    |-- handoffs/
    |-- skills/
    `-- prompts/          # only if actually useful
```

Do not create empty directories merely to satisfy the diagram.

## Classification rule

Use purpose rather than file extension.

If a human maintainer would reasonably read a file to understand the project, it belongs in normal project documentation.

If the file primarily exists so an LLM can resume, understand, or perform work, it belongs under `.llm/`.

Provider-required bootstrap files such as `AGENTS.md` and `CLAUDE.md` are intentional root-level exceptions.

## Root bootstrap files

Keep:

```text
AGENTS.md
CLAUDE.md
```

at the repository root because agent tools may discover these names automatically.

### AGENTS.md

Treat `AGENTS.md` as the main provider-neutral context manifest.

It should explicitly identify the context an agent should read.

Avoid blanket instructions such as:

```text
Read every Markdown file in the repository.
```

Prefer a short explicit sequence such as:

```text
Read the HUMAN and PERSONA context.
Read .llm/working-context.md if present.
Use relevant material from .llm/skills/.
Consult handoffs only when prior work is needed.
```

### CLAUDE.md

Keep `CLAUDE.md` minimal.

Normally it should direct Claude to `AGENTS.md`.

Only genuinely Claude-specific instructions should live there.

## HUMAN and PERSONA

The user currently uses HUMAN and PERSONA files that are largely static and often symlinked to shared material.

Inspect the existing links before changing them.

Preferred eventual location:

```text
.llm/HUMAN.md
.llm/PERSONA.md
```

However, do not move functioning symlinks merely to make the directory tree prettier. Preserve working behavior unless there is a practical benefit to moving them.

## working-context.md

Introduce:

```text
.llm/working-context.md
```

Its purpose is:

> Where is this project now, and what should happen next?

Suggested structure:

```markdown
# Working Context

## Current state

...

## Next

...

## Open questions

...

## Deferred

...
```

It is valid for `Next` to say:

```text
Nothing currently planned.
```

Keep this document small and aggressively pruned.

A typical target is about 200-800 words.

Do not turn it into an append-only journal.

Move durable design or architectural information elsewhere.

## Handoffs

Use:

```text
.llm/handoffs/
```

for useful session and subproject handoffs.

Handoffs should contain compressed semantic state rather than transcripts.

Useful contents may include:

- task
- context/files
- tools
- constraints/permissions
- definition of done
- decisions
- artifacts produced
- immediate next work
- unresolved questions

Do not automatically ignore useful handoffs in Git.

## Skills

Use:

```text
.llm/skills/
```

for reusable agent procedures.

Create a skill only when the procedure is:

- repeatable
- stable enough to maintain
- likely to be useful more than once

Do not promote one-off instructions into permanent `SKILL.md` files.

## Prompts

Use:

```text
.llm/prompts/
```

only if the dotfiles project actually accumulates reusable prompts.

Otherwise omit it.

## Durable documentation

Files such as:

```text
architecture.md
design.md
patterns.md
```

may belong under:

```text
docs/
```

if they are durable project documentation intended to explain the software or configuration to human maintainers.

Inspect each file before moving it.

Do not move files merely because they use Markdown.

## Avoid premature machinery

Do not add:

- YAML front matter
- metadata schemas
- RAG indexing
- automated orchestration
- elaborate provider abstractions
- unnecessary manifests

unless an existing tool actually requires them.

The first implementation should remain simple and obvious.

## Pilot procedure

Before modifying the dotfiles repository:

1. Inventory existing Markdown files.
2. Identify symlinks.
3. Identify provider-specific bootstrap files.
4. Identify handoffs, skills, prompts, working notes, and durable documentation.
5. Classify each file by purpose.
6. Propose the smallest useful reorganization.
7. Preserve Git history and symlink behavior where practical.
8. Avoid unrelated cleanup.

## Optional audit tool

If it stays simple, create a read-only script that reports:

- root Markdown files
- bootstrap files
- HUMAN/PERSONA files
- symlinks
- working-context files
- handoffs
- skills
- reusable prompts
- likely durable documentation
- files that may be misplaced

The audit tool should recommend changes but make none automatically.

## Definition of done

The pilot is complete when:

1. The dotfiles repository has a clear and minimal Markdown/LLM organization.
2. `AGENTS.md` serves as an explicit context entry point.
3. Current project state has a clear home.
4. Handoffs and skills have clear homes.
5. Human-facing documentation remains clearly separate.
6. Existing useful symlink behavior is preserved.
7. No unnecessary directory hierarchy or boilerplate has been introduced.
8. The resulting convention is documented briefly enough to reuse elsewhere.
9. Any audit script is read-only and tested.

## Deliverable back to the `.MD Files` project

After the dotfiles pilot is complete, return a short handoff containing:

- final directory structure
- files moved or created
- decisions made
- things deliberately left unchanged
- audit-script behavior, if created
- problems encountered
- lessons learned
- recommendations before applying the convention to other repositories

The `.MD Files` project should then be updated with the **proven convention**, not merely the original proposal.
