# Shell Login/Profile Restructuring Handoff

## Status

**Design proposal / review requested. Not yet implemented.**

This handoff records a proposed restructuring of the dotfiles shell startup model for Windows Git Bash and Ubuntu/WSL Bash.

The immediate trigger was a regression in the Windows Terminal project launcher: project Bash tabs were supposed to start in the project directory, but instead started in `$HOME`.

The investigation exposed a broader shell-startup design issue and led to the proposal below.

---

# Immediate Bug That Triggered This Work

The Windows Terminal launcher currently passes the project directory with `wt.exe -d`.

The color profiles launch Git Bash with:

```text
C:\Program Files\Git\bin\bash.exe --login -i
```

A Bash login shell reads `~/.bash_profile` before normal interactive Bash startup.

The tracked real Bash login profile currently contains:

```sh
#cd $myroot
cd || return
```

A bare `cd` changes the working directory to `$HOME`.

Therefore the current startup sequence is effectively:

```text
launcher selects project directory
        ↓
Windows Terminal starts there
        ↓
bash --login -i
        ↓
~/.bash_profile
        ↓
cd
        ↓
$HOME
```

This explains why the launcher can correctly capture and pass the project directory while the resulting Git Bash window still opens in the home directory.

The unconditional `cd` should be removed regardless of the larger restructuring.

Shell startup files should configure the shell, not override the working directory chosen by the launching process.

---

# Current Relevant Architecture

The repository uses small files under `real/` that are deployed into `$HOME` by `deploy.sh` and point back to tracked configuration in the repository.

Relevant current files include:

```text
real/.bash_profile  -> bash/bash_profile
real/.profile       -> profile
real/.bashrc         -> bash/bashrc

bash/bash_profile
bash/bashrc
bash/bashrc-common
bash/bashrc-windows
bash/bashrc-ubuntu
sh/shrc
profile
```

## Current `bash/bash_profile`

It currently performs several unrelated responsibilities:

- platform detection
- Windows `set -o igncr`
- sources `~/.bashrc`
- configures `MANPATH`
- configures `INFOPATH`
- unconditionally runs `cd`, sending the shell to `$HOME`
- initializes Windows Miniconda when available

This file has become a mixed login/environment/platform/interactive configuration layer.

## Current `profile`

The tracked `profile` is currently very small:

```sh
export LANG=$(locale -uU)
# Only for interactive sh, not bash
[ -z "${BASH_VERSION-}" ] || return 0
[ -n "${PS1-}" ] || return 0

PS1='[sh] ${PWD##*/}$ '
```

Its current role is mostly to provide a plain-`sh` prompt.

## Current `bash/bashrc-common`

It currently contains several categories of behavior:

- Bash history settings
- Bash `shopt`
- aliases and functions
- common Bash PATH additions
- `ENV="$HOME/dotfiles/sh/shrc"`
- terminal title support

Some of these are genuinely interactive-Bash behavior, while some are better viewed as portable login-environment configuration.

---

# Proposed Model

The preferred model is:

```text
.profile
    portable login environment

.bash_profile
    small Bash login dispatcher

.bashrc
    interactive Bash behavior

sh/shrc
    interactive plain-sh behavior
```

More explicitly:

```text
Bash login shell
    ↓
~/.bash_profile
    ↓
~/.profile
    ↓
~/.bashrc
    ↓
common + platform-specific Bash configuration
```

A plain Bourne/POSIX-style login shell would read:

```text
~/.profile
```

and an interactive plain shell can use:

```text
ENV=$HOME/dotfiles/sh/shrc
```

This keeps the portable login environment separate from Bash-specific interactive behavior.

---

# Proposed `.bash_profile`

Do **not** delete `.bash_profile` entirely.

Keeping it as a tiny Bash-specific dispatcher is considered clearer and leaves an explicit Bash login hook.

Target shape:

```sh
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
```

Its job should be only:

1. load the portable login environment
2. load interactive Bash configuration

It should not contain:

- `cd`
- PATH policy
- aliases
- prompt setup
- platform-specific tool configuration
- Conda initialization
- terminal behavior

---

# Proposed `.profile` Responsibilities

`.profile` should be the boring, portable environment layer.

Candidate responsibilities:

## 1. Portable user PATH entries

Move common login PATH entries such as:

```text
$HOME/bin
$HOME/dotfiles/bin
```

out of `bashrc-common` and into `.profile`.

Because `.profile` must not assume Bash functions such as `pathPrepend` are already loaded, use POSIX-compatible PATH logic.

Example:

```sh
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) [ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH" ;;
esac

case ":$PATH:" in
  *":$HOME/dotfiles/bin:"*) ;;
  *) [ -d "$HOME/dotfiles/bin" ] && PATH="$HOME/dotfiles/bin:$PATH" ;;
esac

export PATH
```

The surrounding colons make the membership check exact and avoid accidental partial matches.

This also makes repeated sourcing idempotent rather than duplicating PATH entries.

## 2. Manual/info search paths

Move the existing login-profile logic for user documentation paths into `.profile`:

```sh
[ -d "$HOME/man" ] &&
  MANPATH="$HOME/man${MANPATH:+:$MANPATH}"

[ -d "$HOME/info" ] &&
  INFOPATH="$HOME/info${INFOPATH:+:$INFOPATH}"

export MANPATH INFOPATH
```

## 3. `ENV` for interactive POSIX-style shells

Move:

```sh
ENV="$HOME/dotfiles/sh/shrc"
export ENV
```

from Bash common configuration into `.profile`.

This is conceptually environment/login configuration rather than Bash-interactive configuration.

## 4. Locale

The current profile contains:

```sh
export LANG=$(locale -uU)
```

This should be reviewed before preserving it unchanged.

The goal is to keep locale configuration in `.profile`, but the exact command should be verified for portability across Git Bash and Ubuntu rather than assumed.

## 5. Future portable environment variables

Good future candidates include things such as:

```text
EDITOR
PAGER
LANG / LC_*
other shell-independent environment variables
```

Only add them when there is an actual need.

---

# What Should Remain in `.bashrc` / `bashrc-common`

Interactive Bash behavior belongs here, including:

- Bash history settings
- `shopt`
- aliases
- Bash functions
- prompt logic
- Bash-specific completion
- direnv interactive hooks
- terminal title updates

These should not move into `.profile` merely because they happen to be executed during login.

---

# What Should Move to `bashrc-windows`

The following current `bash_profile` behavior is Windows/Git-Bash-specific and should move to `bashrc-windows`:

## `igncr`

```sh
set -o igncr 2>/dev/null || true
```

## Windows Miniconda initialization

```sh
if [ -f /c/Users/ray/miniconda3/etc/profile.d/conda.sh ]; then
  . /c/Users/ray/miniconda3/etc/profile.d/conda.sh
fi
```

This keeps Windows-only behavior in the already-existing Windows Bash layer.

Existing Windows-specific Java, Gradle, `myroot`, Anti-Gravity, symlink, and terminal behavior already lives there and should remain platform-specific.

---

# Proposed Responsibility Boundary

The desired rule is:

```text
.profile       = process/login environment
.bash_profile  = Bash login dispatcher
.bashrc        = interactive Bash behavior
sh/shrc        = interactive plain-sh behavior
```

Another way to state it:

- `.profile` answers: **What environment should this user have after login?**
- `.bash_profile` answers: **What should a Bash login shell load?**
- `.bashrc` answers: **How should interactive Bash behave?**
- `sh/shrc` answers: **How should interactive plain sh behave?**

Each file should have one main reason to exist.

---

# Other Shells

One reason for giving `.profile` a real role is to avoid making the environment depend entirely on Bash.

Typical behavior:

```text
bash    .bash_profile / .profile + .bashrc
sh      .profile + ENV
ksh     .profile + ENV
zsh     .zprofile + .zshrc
fish    separate configuration model
```

`.profile` is therefore not literally universal, but it is the natural portable login-environment file for Bourne/POSIX-style shells.

Keeping a minimal `.bash_profile` that explicitly sources `.profile` is intentional, not redundant.

---

# Important Regression Requirement

The restructuring must preserve the working directory selected by the launcher.

A login shell started in a project directory must remain there after all startup files have run.

Add an automated regression test equivalent to:

```text
start shell with working directory X
run login/profile/bash startup
assert final PWD == X
```

This would have caught the current unconditional-`cd` bug.

No shell startup file should contain an unconditional directory change.

---

# Deployment Considerations

The current deployment system copies files from `real/` into the target home directory.

Because the proposal now favors **keeping** `.bash_profile` as a tiny dispatcher, the deployment mechanism does not need special stale-file deletion logic.

Instead:

- keep `real/.bash_profile`
- simplify it or its target so Bash login startup reaches the new minimal dispatcher
- keep `real/.profile`
- update the tracked `profile`
- update validation to match the new load chain

The current README documents the old load chain and will need updating after implementation.

---

# Tests That Should Be Updated or Added

The existing `tests/validate-shell-startup.sh` currently assumes substantial behavior lives in `bash/bash_profile`.

Update it to validate the new responsibility split.

Recommended checks:

1. shell syntax remains valid
2. `.bash_profile` sources `.profile`
3. `.bash_profile` sources `.bashrc`
4. `.bash_profile` does not change directories
5. `.profile` works under POSIX `sh`
6. `.profile` PATH additions are idempotent
7. `.profile` exports `MANPATH`, `INFOPATH`, and `ENV` as intended
8. Windows `igncr` behavior still loads under Git Bash
9. Windows Conda initialization remains Windows-only
10. Ubuntu startup does not load Windows paths
11. Bash aliases/functions/history behavior remains unchanged
12. login startup preserves the caller-selected working directory
13. deployment still puts the correct stubs in the correct home directory

---

# Open Review Questions

A second or third reviewer should specifically examine these points:

## 1. Is the proposed responsibility split sound?

```text
.profile       portable login environment
.bash_profile  thin Bash login dispatcher
.bashrc        interactive Bash
sh/shrc        interactive sh
```

## 2. Should `$HOME/bin` and `$HOME/dotfiles/bin` move from `.bashrc` to `.profile`?

The current proposal says yes so all Bourne-style login shells inherit them.

## 3. Is `ENV="$HOME/dotfiles/sh/shrc"` best established in `.profile`?

The current proposal says yes.

## 4. What is the correct portable locale policy?

The current `LANG=$(locale -uU)` should not be retained blindly without testing Git Bash and Ubuntu behavior.

## 5. Should Windows Conda initialization remain automatic?

The immediate proposal merely moves it into `bashrc-windows`; a reviewer may reasonably question whether automatic Conda initialization should happen at all.

## 6. Should any environment initialization run only for interactive shells?

Review the effect of sourcing `.bashrc` from `.bash_profile`, especially for commands or tools that create noninteractive login Bash shells.

## 7. Are any existing startup variables incorrectly located today?

Review `bashrc-common`, `bashrc-windows`, and `bashrc-ubuntu` for additional login-environment settings that belong in `.profile` or platform-specific environment files.

---

# Implementation Scope

No implementation has been performed as part of this handoff.

The recommended implementation sequence is:

1. create a feature branch
2. add/modify tests first, especially working-directory preservation
3. simplify `bash/bash_profile`
4. expand `profile` into the portable login environment
5. move Windows-specific login behavior to `bashrc-windows`
6. remove migrated PATH/ENV logic from `bashrc-common`
7. update stubs under `real/` only as needed
8. update README startup documentation
9. run shell startup validation under Git Bash
10. run shell startup validation under Ubuntu/WSL
11. manually verify Windows Terminal project launcher opens in the correct project directory
12. merge only after both environments behave correctly

---

# Desired End State

A project launcher should be able to select a working directory and trust the shell to preserve it.

The shell startup architecture should be understandable without memorizing historical accidents:

```text
login environment -> .profile
Bash login glue    -> .bash_profile
Bash interaction   -> .bashrc
sh interaction     -> sh/shrc
platform details   -> bashrc-windows / bashrc-ubuntu
```

The restructuring should improve portability between Windows Git Bash and Ubuntu/WSL while preserving existing prompt, history, terminal-title, Java/Gradle, direnv, and platform-isolation behavior.
