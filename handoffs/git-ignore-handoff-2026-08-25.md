# Git Ignore Policy Handoff

**Date:** 2026-08-25
**Project:** dotfiles / Git configuration

## Purpose

Establish a clear division between:

- the user's global Git excludes file, which handles personal workstation noise and safety defaults; and
- each repository's `.gitignore`, which records shared project policy.

The configured global excludes file has previously been:

```text
~/dotfiles/git/gitignore
```

## Main decision

Use the global excludes file for files that should never be part of any project because they are created by the operating system, editors, IDEs, shells, or crash handlers.

Use each repository's `.gitignore` for build products, dependencies, runtime output, and other rules determined by that project's toolchain.

This matters because the global excludes file exists only on the user's computer. Repository `.gitignore` rules are committed, shared with collaborators and automated workers, and document what the project generates.

## Recommended global excludes file

```gitignore
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini

# Editor backup and swap files
*~
*.swp
*.swo
*.bak

# Vim
.Session.vim
.netrwhist

# Emacs
\#*\#
.\#*

# VS Code local history
.history/

# JetBrains local state
.idea/workspace.xml
.idea/tasks.xml
.idea/usage.statistics.xml
.idea/shelf/

# Shell history
.bash_history

# JVM crash dumps
hs_err_pid*
replay_pid*

# Git Bash and Windows crash dumps
*.stackdump

# Personal secrets safety net
.env
```

`.bash_history` is particularly appropriate globally because the user's `direnv` setup can place per-project Bash history files inside project directories. Shell history is personal state and can contain commands, paths, or sensitive values.

The global `.env` rule is a personal safety net. Applicable repositories should still ignore `.env` themselves so that every clone receives the protection. An exact `.env` rule does not ignore `.env.example` or `.env.sample`.

## Rules that remain repository-specific

Do not rely on the global excludes file alone for:

```gitignore
build/
.gradle/
target/
node_modules/
*.log
*.tmp
.env
```

Reasons:

- `build/` and `.gradle/` describe Gradle-generated state.
- `target/` normally describes Maven-generated state.
- `node_modules/` belongs to Node projects.
- Some repositories intentionally contain log or temporary-file fixtures.
- Secret-file protection such as `.env` should be visible and shared.

A typical Gradle repository might therefore contain:

```gitignore
# Gradle
.gradle/
build/

# Runtime output
*.log
*.tmp

# Local configuration and secrets
.env
```

## Eclipse policy

Do not globally ignore:

```text
.project
.classpath
.settings/
```

For the user's Gradle/Eclipse projects, these files normally describe the shared Eclipse project setup and should generally be committed.

## Negated rules and exceptions

Git permits a repository `.gitignore` to override a lower-priority global exclusion with `!` rules. If the global file ignored `build/`, an exceptional repository could re-include it with:

```gitignore
!build/
!build/**
```

The first rule re-includes the directory and the second re-includes its contents. This mechanism is valid, but it should not replace shared repository ignore rules. If only one exceptional file needs to be committed, `git add -f` is often simpler; once a file is tracked, ignore rules do not affect it.

## Current `dotfiles` repository status

The latest reported untracked files were:

```text
.envrc
openclaw.json.tmp
openclaw.log
publish-utilities/.gradle/
publish-utilities/build/
```

Recommended additions to the `dotfiles` repository's `.gitignore`:

```gitignore
# OpenClaw runtime files
openclaw.json.tmp
openclaw.log

# Gradle-generated files
publish-utilities/.gradle/
publish-utilities/build/
```

Using the paths specific to `publish-utilities` avoids accidentally hiding similarly named directories elsewhere in the dotfiles repository. Broader `*.log` and `*.tmp` rules would also be reasonable if all such files in this repository are runtime output.

## Outstanding decision: `.envrc`

Inspect `.envrc` before deciding:

- Commit it if it contains reusable `direnv` configuration such as the per-project `HISTFILE` setup.
- Ignore it if it contains secrets, private values, or machine-specific absolute paths.
- If it mixes reusable configuration with private values, commit a safe `.envrc.example` and ignore `.envrc`.

Because this is the dotfiles repository, the likely choice is to commit `.envrc` if it is portable and contains no secrets.

## Useful checks

Verify the configured global excludes file:

```bash
git config --global --get core.excludesfile
```

Check whether a particular path is ignored and identify the responsible rule:

```bash
git check-ignore -v -- PATH
```

Check whether `.bash_history` is already tracked:

```bash
git ls-files -- .bash_history
```

If it is tracked, stop tracking it while retaining the local file:

```bash
git rm --cached -- .bash_history
```

## Next actions

1. Add `.bash_history` and `*.stackdump` to the global excludes file.
2. Keep build-system and runtime-output rules in the applicable repositories.
3. Add the OpenClaw and `publish-utilities` rules to the dotfiles repository's `.gitignore`.
4. Inspect `.envrc`, then either commit it or ignore it according to its contents.
5. Run `git status` and `git check-ignore -v` to verify the result.
