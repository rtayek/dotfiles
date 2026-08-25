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
- **Per-project history**: direnv + PROMPT_COMMAND switch HISTFILE to a
  project-local `.bash_history` when a project's `.envrc` calls
  `useProjectHistory`.
- **Direnv helper library**: `.envrc` is normal tracked configuration when it
  contains portable project setup. This repository's tracked `.envrc` loads
  `~/dotfiles/direnv/envrc`.
- **Secrets**: never in this repo. Projects load them via
  `loadCentralSecrets` from `~/.secrets/` (see direnv/envrc).

## Validation

Run:

    bash tests/validate-shell-startup.sh
    bash tests/validate-terminal-settings.sh
    bash tests/validate-git-config.sh

The validators check shell syntax and startup behavior, terminal configuration,
platform separation, project history behavior, Git configuration separation,
Git ignore policy, and generated Git include stubs.

`tests/validate-publish-utilities.sh` additionally validates the local
publish-utilities Gradle workflow when its external utilities JAR is available.

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
state. It simply loads the shared direnv helper library.

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

- Review the semantics of the shared direnv helpers and project `.envrc` use.
- Review the Windows-only global attributes file currently referenced as
  `C:/Users/ray/.config/git/attributes`; decide later whether it belongs in
  this repository.
- Revisit the Windows `safe.directory = G:/pt` exception after confirming why
  that ownership exception is needed.
