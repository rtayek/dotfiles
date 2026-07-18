# dotfiles

Shell and git configuration for Ray's Windows Git Bash and Ubuntu/WSL Bash.

## The big picture

The real configuration lives in this repo. The home directory only gets
tiny one-line stub files that source the repo versions. To install or
repair the stubs, run:

    sh ~/dotfiles/deploy.sh

It copies everything in `real/` to the home directory (except
`.gitignore`, which is a template - see below).

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
      -> ~/.gitconfig             (deployed copy: identity, LF rules)
        -> git/gitignore          (global excludes, via core.excludesfile)

## Directory guide

| Path              | What it is                                        |
|-------------------|---------------------------------------------------|
| `real/`           | Files deployed verbatim to `$HOME` by deploy.sh   |
| `bash/`           | The actual bash configuration                     |
| `sh/`             | Prompt for plain sh                               |
| `git/gitignore`   | Global git excludes (machine-personal stuff)      |
| `direnv/envrc`    | Shared direnv helpers, sourced by project `.envrc` files |
| `profile`         | Real sh profile                                   |
| `deploy.sh`       | Copies `real/*` to the home directory             |

## real/ contents

| File            | Deployed? | Purpose                                  |
|-----------------|-----------|------------------------------------------|
| `.bashrc`       | yes       | stub -> bash/bashrc                       |
| `.bash_profile` | yes       | stub -> bash/bash_profile                 |
| `.bash_aliases` | yes       | stub -> bash/bash_aliases                 |
| `.bash_functions` | yes     | stub -> bash/bash_functions               |
| `.bash_functions-windows` | yes | stub -> bash/bash_functions-windows   |
| `.bash_functions-ubuntu` | yes | stub -> bash/bash_functions-ubuntu     |
| `.profile`      | yes       | stub -> profile                           |
| `.gitconfig`    | yes       | full global git config                    |
| `.gitignore`    | NO        | template to copy into new projects        |

## Notable features

- **Low-vision prompt**: short prompt showing only the current
  directory name (see end of bash/bashrc).
- **Windows Terminal project colors**: `settings.json` keeps project identity
  in the terminal background color. Git Bash profiles use cyan tabs and Bash
  titles prefixed with `WIN`; WSL profiles use orange tabs and Bash titles
  prefixed with `WSL`.
- **Platform split**: common Bash behavior lives in `bash/bashrc-common`;
  Windows Git Bash behavior lives in `bash/bashrc-windows`; Ubuntu/WSL
  behavior lives in `bash/bashrc-ubuntu`.
- **Per-project history**: direnv + PROMPT_COMMAND switch HISTFILE to a
  project-local .bash_history when a project's .envrc calls
  `useProjectHistory`.
- **Direnv helper library**: project or workspace `.envrc` files can load
  reusable helpers with `. "$HOME/dotfiles/direnv/envrc"`.
- **Validation**: run `bash tests/validate-shell-startup.sh` to check shell
  syntax, platform separation, bootstrap targets, prompt, history, and
  preserved Windows paths.
- **Secrets**: never in this repo. Projects load them via
  `loadCentralSecrets` from ~/.secrets/ (see direnv/envrc).

## gitignore cheat sheet

Three ignore files, three jobs:

1. `git/gitignore` - global, applies to every repo on this machine.
   Wired via `core.excludesfile` in .gitconfig. Contains
   machine-personal noise: direnv (.envrc, .env.secrets),
   per-project .bash_history, OS junk (.DS_Store, Thumbs.db),
   vim swap files.
2. `.gitignore` (repo root) - protects this repo itself: swap files,
   .envrc, .bash_history, Google Drive temp (.tmp.driveupload/),
   and *.log.
3. `real/.gitignore` - template for new projects. Currently a
   placeholder; fill with project-build ignores (build/,
   node_modules/, __pycache__/, *.class ...). Never deployed to
   the home directory (deploy.sh skips it).

Rule of thumb: machine-personal stuff goes global; project-build stuff
goes in the project. The home directory needs no .gitignore at all,
since it is not a git repo.

## Editing workflow

1. Edit files in this repo (usually under `bash/`).
2. If you changed anything in `real/`, run `sh deploy.sh`.
3. Open a new terminal to pick up changes.
4. Commit.

## TODO / revisit later

- Review the direnv/.envrc setup: is the .envrc ignore strategy right,
  and are the helpers in direnv/envrc still what we want?
- Review the gitignore contents (all three) - prune or add entries.
- Fill in the real/.gitignore template with a generic project ignore
  list (Java/Gradle, Python, Node).
