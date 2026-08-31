# Handoff: Terminal Titles and Process Identification

**Date:** 2026-08-31  
**Environment:** Windows 11, Windows Terminal, Git Bash, Java 25, Gradle, Eclipse

## Executive Summary

Make every project terminal identify itself by project name and Bash PID. Add a
small Bourne-shell inspection command that correlates terminal, Bash, Git, and
Java processes. Continue terminating processes by exact PID, beginning with the
leaf process; never kill the shared Windows Terminal process merely to recover
one frozen tab.

## Problem

Windows Task Manager displays executable names such as `bash.exe`, `java.exe`,
`OpenConsole.exe`, and `WindowsTerminal.exe`. With several project windows and
tabs, those names do not reveal which process belongs to which project.

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
ChatMap | Bash 33696 | /c/Users/ray/eclipse-workspace/chatmap
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
existing history, directory, or prompt hook. Project launchers should set, for
example:

```sh
PROJECT_TERMINAL_NAME=ChatMap
export PROJECT_TERMINAL_NAME
```

## Process Inspection

The immediate inspection commands are:

```sh
ps -W -f | grep -Ei '[g]it|[b]ash|[j]ava|[t]erminal'
jps -lv
```

Create a reusable `project-processes.sh` in the `bin` repository that presents
the same information more compactly. It should:

- show PID, parent PID, start time, and executable;
- group or label Windows Terminal, OpenConsole, Bash, Git, and Java entries;
- show `jps -lv` output when the JDK tools are available;
- perform inspection only unless an explicit PID is supplied;
- never use broad process-name termination such as killing every `java.exe`.

## Java and Gradle Identification

Java main classes already help `jps -lv` distinguish ChatMap, Gradle, and
Eclipse. Improve Task Manager's command-line display by adding a JVM property to
ChatMap launch tasks:

```text
-Dchatmap.process.label=ChatMap:UI
-Dchatmap.process.label=ChatMap:HandoffWatcher
-Dchatmap.process.label=ChatMap:HandoffOrchestrator
```

Use the appropriate label for each `JavaExec` task. This is diagnostic metadata
only; application behavior must not depend on it.

Gradle daemons should normally be stopped through:

```sh
./gradlew --stop
```

Eclipse also runs as Java and must not be killed merely because Task Manager
shows `java.exe`.

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

1. Add terminal-title support to one project launcher, beginning with ChatMap.
2. Verify the title in Windows Terminal and Task Manager.
3. Add the reusable read-only `project-processes.sh` helper.
4. Add diagnostic JVM labels to ChatMap `JavaExec` tasks.
5. Apply the terminal-title convention to other project launchers.

Keep these as separate, small commits. The first commit should change only the
ChatMap terminal title.

## Definition of Done

- Every project tab visibly shows its project name and Bash PID.
- Task Manager can correlate window title, PID, and command line.
- `project-processes.sh` produces a compact process inventory from Git Bash.
- `jps -lv` distinguishes Eclipse, Gradle, and ChatMap Java processes.
- A frozen Git operation can be identified and terminated without closing
  unrelated project tabs.
- No broad process-name kill command is part of the normal workflow.

## Constraints

- Use Bourne-shell-compatible commands from Git Bash.
- Do not require PowerShell for normal operation.
- Preserve existing per-project history and prompt hooks.
- Keep displayed titles short enough for low-vision scanning.
- Treat process termination as an explicit PID-based operation.
