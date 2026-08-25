# Project Browser / Workspace Launcher Handoff

## Goal

Create a simple way to launch a dedicated browser window for each major development project.

The user often works on several projects at once and wants to switch between them easily.

Each project should have its own browser window containing the web resources normally used for that project, such as:

- ChatGPT
- Claude
- other LLMs
- the project's GitHub repository
- project-specific documentation or other useful sites

Several project browser windows may remain open simultaneously.

Example conceptual usage:

```sh
project-browser dotfiles
project-browser chatmap
project-browser garden
```

## Desired model

Prefer:

```text
one generic launcher
        +
one small URL/configuration definition per project
        =
one browser window per project
```

Do not create a separate custom shell script for every project unless there is a strong reason.

Project URL sets should be data/configuration rather than duplicated launcher logic.

## Existing work

The dotfiles repository already contains an `open-three-urls.sh` script.

It currently:

- is POSIX `/bin/sh`
- accepts an optional browser, defaulting to Chrome
- supports Chrome, Edge, Brave, and Firefox
- accepts exactly three URLs
- knows about Git Bash `/c` and WSL `/mnt/c` paths
- locates the Windows browser executable
- uses `MSYS2_ARG_CONV_EXCL='*'`
- opens a new browser window

This is probably the starting point rather than something to discard.

The likely next step is to generalize it from "open exactly three URLs" into a project-oriented launcher.

## Important distinction

Browser project windows and Windows Terminal project identity are related but separate systems.

Current terminal scheme:

- project identity = background color
- environment identity = WIN / WSL24 / OLD, plus tab color

Do not unnecessarily couple browser behavior to terminal colors or profiles.

The browser launcher should primarily answer:

> Open the web workspace for this project.

## Questions to investigate

1. How should project URL definitions be stored?
   - one simple file per project
   - shell-readable configuration
   - one central configuration file
   - another minimal format

2. How should project names map to browser windows?

3. Can browser windows be given useful titles or otherwise made easy to identify?

4. What happens if a project's browser window is already open?
   - open another
   - reuse/focus existing window
   - initially keep behavior simple

5. Should the launcher work identically from:
   - Windows Git Bash
   - Ubuntu/WSL

6. Should the number of URLs be unlimited rather than fixed at three? Probably yes.

7. Browser support:
   - Chrome is currently the default
   - Edge, Brave, Firefox already have partial support
   - preserve multiple-browser capability if it stays simple

## Design preferences

Keep it:

- simple
- command-line driven
- POSIX shell where practical
- configuration-driven
- testable
- cross-platform where useful
- free of unnecessary abstractions

Prefer extending the existing script over building a large new framework.

## Likely first prototype

Something approximately like:

```sh
project-browser dotfiles
```

which reads:

```text
projects/dotfiles.urls
```

and launches one browser window containing every URL listed there.

Example configuration concept:

```text
https://chatgpt.com/
https://claude.ai/
https://github.com/rtayek/dotfiles
```

The exact file location and format are not yet decided.

## Repository context

Repository:

```text
https://github.com/rtayek/dotfiles
```

The browser-launcher work is already recorded in the dotfiles README worklist.

Do the browser-launcher design and implementation in this separate chat, then return a short handoff to the main dotfiles chat containing:

- chosen command/interface
- configuration layout
- browser/window behavior
- Windows/WSL decisions
- files changed
- tests
- remaining questions