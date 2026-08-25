# Dotfiles Project Handoff (Durable State)

## Current Status

The recent cross-platform shell and Windows Terminal work is complete.

A feature branch was developed, tested, merged into `master`, and pushed.

The repository is currently in a clean state.

## Current working arrangement (2026-08-25)

Dotfiles work is handled in the main dotfiles chat.

The WSL development migration is currently being worked on in a separate chat.
This is an organizational convenience, not a change to the dotfiles project's
goals or priorities.

---

# Primary Direction

The highest priority is **not** additional shell-script cleanup.

The primary objective is to migrate everyday software development from Windows/Git Bash to Ubuntu running under WSL2 while keeping Windows as the desktop operating system.

This repository should support that migration.

---

# Current Architecture

## Shell startup

Shell startup is organized into:

* `bashrc-common`
* `bashrc-windows`
* `bashrc-ubuntu`

Common behavior belongs in the common layer.

Platform-specific behavior belongs only in the platform layer.

Avoid duplicating startup logic.

---

## Windows Terminal

Project identity now consists of two independent concepts.

### Project

Projects are distinguished by background color.

Examples:

* Red
* Green
* Blue
* Cyan
* Magenta
* Yellow

These colors identify projects.

### Environment

Environment is identified independently.

Git Bash:

* tab title prefix: `WIN`
* cyan tab color

Ubuntu 24.04 / WSL (`wsl.exe -d Ubuntu-24.04`, the primary distro):

* tab title prefix: `WSL24`
* orange tab color

Old Ubuntu 22.04 distro (`wsl.exe -d Ubuntu`, kept reachable for continuity):

* tab title prefix: `OLD`
* purple tab color

Typical titles become:

```
WIN - dotfiles
WSL24 - myclaw
```

This allows identical project colors to exist in every environment while remaining visually distinguishable.

The `WSL ___` profiles previously targeted `wsl.exe -d Ubuntu` — the old 22.04 distro — by mistake. They are now `WSL24 ___` and target `Ubuntu-24.04`.

Open question: whether the old `Ubuntu` (22.04) distro should eventually be uninstalled and the `Ubuntu ___` profiles removed.

### Deployment

`deploy.sh` deploys `settings.json` to the live Windows Terminal path (`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`) when running under Windows/Git Bash, in addition to copying the `real/.*` dotfiles to `$HOME`.

---

# Testing

Automated tests now verify:

* shell startup
* Windows Terminal configuration
* title generation
* platform separation
* environment isolation

A previous bug caused Linux startup tests to inherit the Windows `myroot` environment variable.

The tests now explicitly isolate inherited environment variables.

Continue expanding automated validation rather than relying on manual testing.

---

# Git Workflow

Preferred workflow:

1. create feature branch
2. implement change
3. run tests
4. push feature branch
5. merge with `--no-ff`
6. rerun tests on `master`
7. push `master`

This workflow worked well and should remain the standard.

---

# Eclipse / Gradle

Gradle remains the authoritative build system.

Eclipse is an IDE.

Do **not** globally ignore:

```
.project
.classpath
.settings/
```

Whether Eclipse metadata is tracked should be decided **per repository**.

Some Gradle projects may legitimately track Eclipse metadata.

Others should ignore it locally.

Avoid global policy.

---

# Script Organization

This is currently **low priority**.

Tentative direction:

## dotfiles/bin

Contains workstation configuration and maintenance commands.

Examples:

* Windows Terminal configuration
* Mintty configuration
* Git configuration inspection
* dotfile inspection

This directory does **not** need to be on PATH.

---

## bin repository

Contains reusable commands intended to be executed directly.

Examples include Git utilities and general shell tools.

This repository remains on PATH.

---

Project-specific scripts belong inside their respective projects.

No additional repository restructuring is currently required.

---

# WSL Migration

This is now the primary effort.

Goals:

* perform normal development inside Ubuntu
* keep repositories inside the Linux filesystem
* use Linux Git
* use Linux Java
* use Linux Gradle
* use Linux Python
* use Linux Node
* run Eclipse under WSLg
* use Windows primarily as the desktop host

Migration should be incremental.

Do not attempt to migrate every project simultaneously.

Use Git synchronization between Windows and Linux copies rather than sharing working trees across filesystems.

---

# Design Philosophy

Prefer:

* simple
* testable
* platform-separated
* command-line first
* reproducible

Configuration should be generated from version-controlled files whenever practical.

Tests should describe expected behavior.

Avoid machine-specific assumptions leaking into common startup logic.

---

# Immediate Next Work

Focus on enabling complete development workflows under Ubuntu/WSL2.

The `bin` versus `dotfiles/bin` organization can wait until after the development environment migration is substantially complete.
