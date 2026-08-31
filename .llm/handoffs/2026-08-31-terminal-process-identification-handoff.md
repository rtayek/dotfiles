# Handoff: Terminal Titles and Process Identification

**Date:** 2026-08-31
**Environment:** Windows 11, Windows Terminal, Git Bash, WSL/Ubuntu

## Executive Summary

Make every project terminal identify itself by project name and Bash PID. Add a
small Bourne-shell inspection command that correlates terminal, Bash, Git, and
(where relevant) Java processes. Terminate processes by exact PID, beginning
with the leaf process; never kill the shared Windows Terminal process merely to
recover one frozen tab.

This is a cross-project problem, not specific to any one project, so it belongs
in `dotfiles` alongside the existing shell/terminal infrastructure (bashrc
split, Windows Terminal profiles, per-project launchers).

## Problem

Windows Task Manager displays executable names such as `bash.exe`, `java.exe`,
`OpenConsole.exe`, and `WindowsTerminal.exe`. With several project windows and
tabs open at once, those names do not reveal which process belongs to which
project.

A recent frozen Git operation illustrated the problem:

- one Windows Terminal process owned many tabs;
- each tab had an `OpenConsole.exe` and a `bash.exe`;
- one Bash process owned the stuck `git.exe` and `git-remote-https.exe`;
- killing the Git PID recovered the tab without disturbing the others.

## Goals

1. Show the project name and Bash PID in every terminal-tab title.
2. Make Task Manager's PID, command-line, and window-title columns useful.
3. Provide one short Bourne-shell command for inspecting relevant processes.
4. Make it easy to terminate one Git, Java, or Bash process without killing
   unrelated terminals.
5. Integrate this with the existing per-project launchers.

## Proposed Terminal Title

Use a compact, compatibility-safe title:

```text
<ProjectName> | Bash <PID> | <working directory>
```

The launcher should set a stable project label. Bash may refresh the PID and
working directory through `PROMPT_COMMAND` using the standard terminal-title
escape sequence:

```sh
set_project_terminal_title() {
    printf '\033]0;%s | Bash %s | %s\007' \
        "${PROJECT_TERMINAL_NAME:-${PWD##*/}}" "$$" "$PWD"
}
```

Integrate this with the existing `PROMPT_COMMAND`; do not blindly overwrite an
existing history, directory, or prompt hook. Each project's launcher sets one
variable, e.g.:

```sh
PROJECT_TERMINAL_NAME=MyProject
export PROJECT_TERMINAL_NAME
```

`PROJECT_TERMINAL_NAME` is the only per-project piece of this convention.
Everything else below is shared infrastructure.

## Process Inspection

The immediate inspection commands are:

```sh
ps -W -f | grep -Ei '[g]it|[b]ash|[j]ava|[t]erminal'
jps -lv   # only meaningful on projects that run a JVM
```

Create a reusable `project-processes.sh` in `dotfiles/bin` that presents the
same information more compactly. It should:

- show PID, parent PID, start time, and executable;
- group or label Windows Terminal, OpenConsole, Bash, Git, and (when present)
  Java entries;
- show `jps -lv` output when the JDK tools are available, skip it silently
  otherwise;
- perform inspection only unless an explicit PID is supplied;
- never use broad process-name termination such as killing every `java.exe`.

## Java/JVM Process Identification (project-specific, optional)

Projects that run a JVM can improve Task Manager's command-line display by
adding a diagnostic JVM property to their launch tasks, e.g.:

```text
-D<project>.process.label=<Project>:<Component>
```

Use a label per distinct long-running JVM process (UI, background watcher,
etc.) so `jps -lv` and Task Manager can tell them apart. This is diagnostic
metadata only; application behavior must not depend on it. This section lives
in each project's own build files, not in `dotfiles` — it's noted here only
because it complements the same process-identification goal.

Gradle daemons should normally be stopped through:

```sh
./gradlew --stop
```

Any project's own build/IDE tooling (e.g. Eclipse) also runs as Java and must
not be killed merely because Task Manager shows `java.exe`.

## Safe Termination Procedure

1. Identify the exact process and PID.
2. Terminate the leaf process first, such as a stuck Git or provider process.
3. Use the Bash builtin where the process has an MSYS PID:

```sh
kill -TERM PID
kill -KILL PID
```

4. Kill the owning Bash process only if the leaf process does not release the
   tab.
5. Do not kill `WindowsTerminal.exe`; it is shared by many tabs.
6. Remove a Git lock file only after confirming that no Git process remains.

## Implementation Steps

1. Add terminal-title support to one project launcher as a pilot.
2. Verify the title in Windows Terminal and Task Manager.
3. Add the reusable read-only `project-processes.sh` helper to `dotfiles/bin`.
4. Wire `PROJECT_TERMINAL_NAME` into the shared terminal-title logic
   (`bashrc-windows` or equivalent) so any project only needs to set one
   variable.
5. Apply the terminal-title convention to the remaining project launchers.

Keep these as separate, small commits. The first commit should change only the
pilot project's terminal title.

## Definition of Done

- Every project tab visibly shows its project name and Bash PID.
- Task Manager can correlate window title, PID, and command line.
- `project-processes.sh` produces a compact process inventory from Git Bash,
  usable from any project.
- A frozen Git operation can be identified and terminated without closing
  unrelated project tabs.
- No broad process-name kill command is part of the normal workflow.

## Constraints

- Use Bourne-shell-compatible commands from Git Bash.
- Do not require PowerShell for normal operation.
- Preserve existing per-project history and prompt hooks.
- Keep displayed titles short enough for low-vision scanning.
- Treat process termination as an explicit PID-based operation.
