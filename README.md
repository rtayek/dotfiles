# dotfiles

Shell and Git configuration for Ray's Windows Git Bash and Ubuntu/WSL Bash.

## The big picture

The real configuration lives in this repo. The home directory gets small
stub files that point back into the repository. To install or repair them, run:

    sh ~/dotfiles/deploy.sh

`deploy.sh` copies everything in `real/` to the target home directory,
generates a small platform-aware `~/.gitconfig`, and, under Windows/Git Bash,
deploys `settings.json` to Windows Terminal.

## Who's on first (the load chain)

    Bash login
      -> ~/.bash_profile          (stub)
        -> bash/bash_profile      (real: platform login setup)
          -> ~/.bashrc            (stub)
            -> bash/bashrc        (real: platform dispatcher)
              -> bash/bashrc-common
              -> ~/.bash_aliases  (stub)
                -> bash/bash_aliases
              -> ~/.bash_functions (stub)
                -> bash/bash_functions
              -> bash/bashrc-windows or bash/bashrc-ubuntu
                -> bash/bash_functions-windows or bash/bash_functions-ubuntu
              -> bash/bashrc-project-history
              -> ENV=sh/shrc      (prompt for plain sh sessions)

    Plain sh login
      -> ~/.profile               (stub)
        -> profile                (real: sh prompt)

    Any git command
      -> ~/.gitconfig             (generated include stub)
        -> git/gitconfig-common
        -> git/gitconfig-windows or git/gitconfig-ubuntu
          -> git/gitignore        (global excludes, via core.excludesfile)

## Directory guide

| Path                    | What it is |
|-------------------------|------------|
| `real/`                 | Files deployed verbatim to `$HOME` by deploy.sh |
| `bash/`                 | The actual Bash configuration |
| `sh/`                   | Prompt for plain sh |
| `git/gitconfig-common`  | Git settings shared by Windows and Ubuntu |
| `git/gitconfig-windows` | Windows/Git Bash-specific Git settings |
| `git/gitconfig-ubuntu`  | Ubuntu/WSL-specific Git settings |
| `git/gitignore`         | Global Git excludes: personal workstation noise and safety defaults |
| `direnv/envrc`          | Shared direnv helpers, sourced by project `.envrc` files |
| `docs/`                 | Durable human-facing project notes |
| `.llm/`                 | Agent working context, handoffs, and reusable LLM material |
| `profile`               | Real sh profile |
| `deploy.sh`             | Deploys home stubs, Git config includes, and Windows Terminal settings |

## real/ contents

Everything in `real/` is deployed to the target home directory.

| File | Purpose |
|------|---------|
| `.bashrc` | stub -> bash/bashrc |
| `.bash_profile` | stub -> bash/bash_profile |
| `.bash_aliases` | stub -> bash/bash_aliases |
| `.bash_functions` | stub -> bash/bash_functions |
| `.bash_functions-windows` | stub -> bash/bash_functions-windows |
| `.bash_functions-ubuntu` | stub -> bash/bash_functions-ubuntu |
| `.profile` | stub -> profile |
| `.minttyrc` | Mintty configuration |

## Notable features

- **Low-vision prompt**: short prompt showing only the current directory name
  (see end of bash/bashrc).
- **Windows Terminal project colors**: `settings.json` keeps project identity
  in the terminal background color. Git Bash profiles use cyan tabs and Bash
  titles prefixed with `WIN`; WSL profiles use orange tabs and Bash titles
  prefixed with `WSL`.
- **Platform split**: common Bash behavior lives in `bash/bashrc-common`;
  Windows Git Bash behavior lives in `bash/bashrc-windows`; Ubuntu/WSL
  behavior lives in `bash/bashrc-ubuntu`.
- **Git platform split**: shared Git behavior lives in `git/gitconfig-common`;
  platform-only settings live in `git/gitconfig-windows` or
  `git/gitconfig-ubuntu`. `deploy.sh` generates `~/.gitconfig` with the
  appropriate includes.
- **Per-project history**: a project's `.envrc` calls `useProjectHistory`.
  That captures the directory where it was called and keeps one
  `.bash_history` there while shells move through subdirectories.
- **Direnv helper library**: `.envrc` is normal tracked configuration when it
  contains portable project setup. This repository's tracked `.envrc` loads
  `~/dotfiles/direnv/envrc` and explicitly opts into project history.
- **Secrets**: never in this repo. Projects that actually need API keys or
  other credentials explicitly call `loadCentralSecrets`; projects that do
  not need secrets do not load them.

## Validation

Run:

    bash tests/validate-shell-startup.sh
    bash tests/validate-terminal-settings.sh
    bash tests/validate-git-config.sh
    bash tests/validate-project-history.sh

The validators check shell syntax and startup behavior, terminal configuration,
platform separation, project history behavior, Git configuration separation,
Git ignore policy, and generated Git include stubs.

`tests/validate-publish-utilities.sh` additionally validates the local
publish-utilities Gradle workflow when its external utilities JAR is available.

## Markdown and LLM context

Root Markdown is reserved for entry points such as `README.md`, `AGENTS.md`,
and provider-specific bootstrap files. Durable notes for human maintainers live
in `docs/`. Agent working state lives in `.llm/`, with current state in
`.llm/working-context.md` and prior handoffs in `.llm/handoffs/`.

The root `human.md` and `persona.md` files may be shared links. Preserve that
behavior unless there is a practical reason to change it.

## Git ignore policy

There are two relevant ignore files:

1. `git/gitignore` is the user's global excludes file. It applies to every
   repository on this workstation through `core.excludesfile`. It contains
   personal workstation noise and safety defaults such as OS metadata, editor
   backup files, shell history, crash dumps, and `.env`.
2. `.gitignore` at the repository root records policy specific to this
   dotfiles repository, including OpenClaw runtime files,
   `publish-utilities` Gradle output, and `.tmp.driveupload/`.

Repository build products and toolchain rules belong in each repository's
`.gitignore`, not in the global excludes file.

Eclipse metadata is not globally ignored. Whether `.project`, `.classpath`,
and `.settings/` are tracked is decided per repository.

The tracked `.envrc` in this repository is reusable configuration, not private
state. It loads the shared direnv helper library and calls `useProjectHistory`.
Secret loading and other environment behavior are explicit opt-ins.

## Editing workflow

1. Create a feature branch.
2. Edit files in this repo.
3. If deployment behavior or files under `real/` or `git/` changed, run
   `sh deploy.sh` in the applicable environment.
4. Run the relevant validators.
5. Push the feature branch.
6. Merge with `--no-ff`.
7. Rerun the validators on `master`.
8. Push `master`.

## TODO / revisit later

- Build a project browser/workspace launcher: one command per major project
  should open a dedicated browser window with that project's LLMs, GitHub page,
  and other useful web resources. Keep project URL sets in small configuration
  files rather than creating one-off launcher scripts for every project.
- Replace or supplement the machine-specific `.java-home` mechanism with a
  portable project Java-version mechanism when multiple JDKs become necessary.
- Review the Windows-only global attributes file currently referenced as
  `C:/Users/ray/.config/git/attributes`; decide later whether it belongs in
  this repository.
- Revisit the Windows `safe.directory = G:/pt` exception after confirming why
  that ownership exception is needed.
