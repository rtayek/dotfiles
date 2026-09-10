# Working Context

## Current state

This repository holds Ray's shell, Git, terminal, direnv, project-launcher,
and workstation configuration. The shell startup restructure is complete and
working in both Windows Git Bash and Ubuntu/WSL. Git ignore policy and audit
tooling are also in place.

Project launching is now centered on:

- `bin/launch-webterms.sh` as the project-to-port registry
- `templates/project-home.html.macro` as the browser launcher template
- per-project `.envrc` files for project identity and shell history
- `new-project.sh` in the separate `bin` repository as the front-door setup
  helper

The browser workflow uses a saved Chrome tab group per project with
`project-home.html` as the anchor tab. Per-project Windows Terminal profiles are
not required; terminal identity comes from `.envrc` and the shell title logic.

`new-project.sh` now treats the project directory as the unique webterm key.
Rerunning setup for an already-registered project reuses its existing port,
and an explicit conflicting port is rejected. The duplicate Clipboard registry
entry was removed; Clipboard uses port 1036.

A first-cut vanilla Java/Gradle/Eclipse template now lives at
`templates/gradle-eclipse-java/`. It was derived from the `clipboard` project
and has been tested with Java 25, the Gradle wrapper, Eclipse, JUnit 5, `src/`
and `tst/`, and visible Gradle test logging.

The dotmdfiles deployment was refreshed while setting up Clipboard, and the new
project setup flow is usable. The separate Gradle project-creation helper is on
hold for now.

## Current direction

Treat dotfiles as mostly maintenance work. Finish only small cleanup items that
make the existing workflow dependable, then return attention to ChatMap.

WSL migration remains a longer-term direction, but it is not the current
priority.

## Open items

- Preserve the executable bit on
  `templates/gradle-eclipse-java/gradlew` for Linux/WSL use.
- Keep the Gradle/Eclipse project-creation helper deferred until a real need
  justifies finishing it.

## Deferred

- Broad shell style cleanup unless it fixes a concrete problem.
- Further browser-workspace automation unless the manual saved-group workflow
  becomes annoying.
- Moving everyday development fully to WSL until higher-priority ChatMap work
  is in better shape.

## Resolved

- Shell startup V3 is implemented and tested.
- `dotfiles/bin/launch-webterms.sh` is the authoritative webterm registry.
- `new-project.sh` is idempotent for already-registered project directories.
- Duplicate Clipboard webterm registration has been removed.
- No per-project Windows Terminal profile is needed.
- Project identity is supplied by `.envrc` and reflected in terminal titles.
- The project-home launcher pattern works end to end.
- Common Git ignore policy is centralized, while repositories may still keep
  project-specific ignore rules.
- A usable first-cut Gradle/Java/Eclipse template exists in `dotfiles`.
