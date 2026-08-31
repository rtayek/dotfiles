# Shell Startup Restructuring Proposal V2

## Status

**Design proposal for review. Do not merge the current implementation yet.**

This handoff supersedes the earlier shell-login/profile restructuring proposal for review purposes. It incorporates:

- the original launcher bug investigation,
- the current `fix/shell-startup-restructure` implementation (`46b1287`),
- Claude's independent review,
- Codex's review of the Anti-Gravity implementation,
- direct inspection of the current GitHub branch,
- and the live-vs-tracked startup-file diff performed on Windows.

The basic responsibility split still looks sound. The migration ordering and behavioral tests need to be corrected before merge.

---

# Scope

Keep this change narrowly about shell startup semantics.

In scope:

- preserving the launcher's selected working directory,
- Bash login startup,
- Bash non-login interactive startup,
- portable login environment,
- WSL imported-Windows-`HOME` recovery,
- early Git-for-Windows CRLF tolerance,
- shell-startup tests,
- repository LF policy for shell files,
- README/startup documentation.

Explicitly deferred:

- `.bash_secrets` / API-key cleanup,
- redesigning Conda behavior,
- unrelated Git configuration failures,
- unrelated dotfiles cleanup.

The live `~/.bashrc` currently has an extra `.bash_secrets` hook. Ignore it for this restructuring. The live `~/.bash_profile` also has an extra `.bashrc` source line; that should not be preserved because the proposed tracked login dispatcher will source `.bashrc` itself.

---

# Root Cause of the Original Bug

Windows Terminal launches Git Bash profiles with:

```text
C:\Program Files\Git\bin\bash.exe --login -i
```

The project launcher correctly chooses the project directory with `wt.exe -d`.

The tracked Bash login profile then contained:

```sh
cd || return
```

A bare `cd` changes to `$HOME`, destroying the launcher's selected working directory.

Therefore:

```text
launcher selects project directory
        ↓
Windows Terminal starts there
        ↓
bash --login -i
        ↓
.bash_profile
        ↓
cd
        ↓
$HOME
```

The unconditional `cd` must remain removed. Shell startup files should never override a working directory deliberately selected by the launching process.

This bug affected the shared Bash login path and was not fundamentally Windows-only.

---

# What the Current Anti-Gravity Branch Gets Right

Current branch:

```text
fix/shell-startup-restructure
```

Current implementation commit under review:

```text
46b1287f2080e2f84e2164c91e04408c9fafa532
```

Good decisions in that branch:

- removes the unconditional `cd`,
- keeps `.bash_profile` as a Bash login hook rather than deleting it,
- moves toward a `.profile` / `.bash_profile` / `.bashrc` responsibility split,
- updates startup documentation,
- attempts to add PWD-preservation coverage,
- makes PATH additions idempotent,
- removes some duplicated environment setup from `bashrc-common`.

The branch should be repaired, not discarded merely because the first pass has blockers.

---

# Confirmed Blockers in `46b1287`

## 1. WSL wrong-HOME recovery happens too late

The branch's `bash/bash_profile` is currently essentially:

```sh
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
```

But `.profile` now derives HOME-based state such as:

```text
$HOME/bin
$HOME/dotfiles/bin
ENV=$HOME/dotfiles/sh/shrc
MANPATH / INFOPATH
```

The Ubuntu recovery of an imported Windows `HOME` still occurs later inside `bash/bashrc`.

So the broken ordering is:

```text
.profile derives values from wrong Windows HOME
        ↓
.bashrc finally repairs HOME
        ↓
already-derived environment remains wrong
```

Codex reproduced the failure with a deliberately wrong WSL HOME. Claude independently predicted the same regression from code inspection.

The implementation also removed existing `ENV` assertions that would have exposed this regression. Those assertions should be restored and strengthened.

---

## 2. The new login test is not a real login test

The current test named `run_login_probe` still launches:

```sh
bash --noprofile --norc -i -c ...
```

and manually sources `bash/bash_profile`.

That explicitly bypasses Bash's login-file selection and the deployed `real/.bash_profile` stub.

This is the same structural test gap that allowed the original `cd` bug to survive.

A real behavioral test must drive Bash through its actual login mechanism, using a temporary home containing the deployed stubs.

At minimum it must prove:

```text
start in directory X
        ↓
bash --login ...
        ↓
real/.bash_profile
        ↓
tracked login startup chain
        ↓
PWD is still X
```

It also must exercise the WSL wrong-HOME recovery path through the real stub chain.

---

## 3. `igncr` runs too late

The branch moved:

```sh
set -o igncr
```

from early login startup into `bashrc-windows`.

That is too late if earlier sourced files have CRLF endings. `igncr` only protects parsing after it has been enabled.

The repository currently does not reliably enforce LF for all shell startup files, and CRLF has already existed in tracked shell material.

`igncr` therefore belongs in the earliest Windows Bash bootstrap step, before sourcing `.profile`, `.bashrc`, aliases, functions, or other tracked shell files.

Separately, repository-level `.gitattributes` should pin shell startup files to LF so startup correctness does not depend on machine-global Git configuration.

---

## 4. Debug output is committed

The branch's `profile` begins with a diagnostic `echo`.

Login startup must be silent unless intentionally interactive output is required.

Remove the debug output.

---

## 5. Locale handling should preserve the inherited environment

The branch attempts to calculate/fallback `LANG` using `locale -uU` and `en_US.UTF-8`.

Problems:

- `locale -uU` is not portable to GNU/glibc Ubuntu,
- Codex found Ubuntu systems where `en_US.UTF-8` is not installed,
- under `set -u`, testing an unset `LANG` unsafely can abort,
- login/session infrastructure should normally supply locale.

Proposal:

```text
Do not manufacture LANG during this refactor.
Preserve the inherited locale unless a separate demonstrated locale problem requires policy.
```

---

## 6. MANPATH / INFOPATH should not be migrated as currently written

The old code was effectively dead because it was not exported.

The branch makes it exported but introduces behavioral problems:

- repeated sourcing can duplicate values,
- MANPATH's empty component has special semantics,
- omitting the trailing empty component can suppress normal system man paths,
- Codex reproduced a failing `man` lookup after the proposed setup.

Proposal:

```text
Remove MANPATH and INFOPATH handling from this restructuring.
```

If private manual/info trees are actually needed later, design and test that behavior separately.

---

## 7. Non-login Bash must be handled deliberately

Moving all portable HOME-based environment setup from `bashrc-common` into `.profile` creates a new asymmetry:

```text
login Bash      -> .profile -> gets environment
non-login Bash  -> .bashrc   -> may miss that environment
```

The current branch can therefore lose `$HOME/bin`, `$HOME/dotfiles/bin`, `ENV`, and other moved settings in a fresh non-login interactive Bash.

Non-login Bash is a supported and common invocation mode and should not silently receive a different environment policy.

---

# Revised Responsibility Model

The desired conceptual model remains:

```text
.profile       = portable login entry point
.bash_profile  = Bash login bootstrap + dispatcher
.bashrc        = interactive Bash entry point
sh/shrc        = interactive plain-sh behavior
```

However, the implementation needs two reusable layers underneath those entry points:

```text
Bash bootstrap          = establish a safe/correct context before HOME-based setup
portable environment    = establish shell-independent environment policy idempotently
```

A useful conceptual graph is:

```text
                         +----------------------+
                         | Bash bootstrap       |
                         | - early igncr        |
                         | - repair WSL HOME    |
                         +----------+-----------+
                                    |
              +---------------------+--------------------+
              |                                          |
        Bash login                               non-login Bash
              |                                          |
        .bash_profile                                  .bashrc
              |                                          |
              v                                          v
          .profile                              portable environment
              |                                          |
              v                                          v
     portable environment                         Bash interaction
              |
              v
           .bashrc
              |
              v
       Bash interaction

plain sh login
      |
   .profile
      |
      v
portable environment
      |
      v
ENV -> sh/shrc for interactive sh
```

The exact filenames for the reusable layers are open for review. For example:

```text
bash/bootstrap
shell/environment
```

or equivalent names consistent with the repository.

The important point is responsibility and ordering, not the names.

---

# Proposed Bash Bootstrap

Bash login and Bash non-login startup both need a small Bash-specific bootstrap before deriving HOME-based paths.

Responsibilities:

1. detect Windows Git Bash vs Linux/Ubuntu,
2. on Windows, enable `igncr` as early as possible,
3. on Ubuntu/WSL, repair an imported Windows-looking `HOME`,
4. do not change `PWD`,
5. do not load aliases, prompts, Conda, project history, or other interactive policy.

This logic can be factored so `.bash_profile` and `.bashrc` do not duplicate it.

The existing Ubuntu HOME-repair behavior in `bash/bashrc` is valuable and should be preserved, but moved/reused early enough that `.profile` and portable environment setup never derive values from the wrong HOME during Bash startup.

The deployed `real/.bash_profile` Linux-routing behavior also remains important because it can locate the Linux dotfiles checkout even when Bash initially sees a Windows HOME.

---

# Proposed Portable Environment Layer

Create one POSIX-sh-compatible, idempotent implementation of portable environment policy.

Candidate responsibilities:

- add `$HOME/bin` to PATH if it exists and is not already present,
- add `$HOME/dotfiles/bin` to PATH if it exists and is not already present,
- export the resulting PATH,
- establish `ENV="$HOME/dotfiles/sh/shrc"` for plain-sh interactive startup,
- other genuinely portable exported preferences only when there is a demonstrated use.

Do not put Bashisms here.

Do not put prompts, aliases, history, terminal-title behavior, Conda, Java/Gradle Windows paths, platform-specific toolchains, or direnv interactive hooks here.

Do not change the working directory.

Do not force `LANG`.

Do not include MANPATH/INFOPATH in this refactor.

The implementation should be safe to source more than once so both login and non-login paths can reuse it without duplicate PATH entries.

`.profile` should use this layer.

`.bashrc` should also ensure this layer has run after Bash bootstrap, so non-login interactive Bash gets the same portable environment policy as login Bash.

---

# Proposed `.profile`

`.profile` should remain POSIX-sh-compatible.

Its responsibilities should be small:

1. source/apply the portable environment layer,
2. act as the login entry point for plain `sh`,
3. avoid Bash-only syntax,
4. avoid platform-specific Bash bootstrap logic,
5. avoid side effects such as `cd` or diagnostic output.

Existing plain-sh prompt behavior may remain below the Bash guard, or may continue to live in `sh/shrc` if that is cleaner. The key invariant is that portable environment policy executes before returning for Bash.

Conceptually:

```sh
# portable environment
. .../shell/environment

# Bash gets environment only from this file; Bash interaction is elsewhere.
[ -z "${BASH_VERSION-}" ] || return 0

# plain-sh-specific login behavior, if any
...
```

For plain `sh`, `ENV` then points interactive sessions to `sh/shrc`.

Open question for reviewers: if plain `sh` under WSL must recover from an externally wrong Windows HOME, that needs a POSIX-compatible bootstrap design. The current critical requirement is to preserve the already-supported Bash WSL recovery path.

---

# Proposed `.bash_profile`

Keep `.bash_profile`, but make it a small login bootstrap/dispatcher rather than deleting it.

Conceptual sequence:

```text
1. establish Bash startup directory / locate tracked configuration
2. run Bash bootstrap
   - Windows igncr immediately
   - Ubuntu/WSL HOME repair before HOME-derived environment
3. source ~/.profile
4. source ~/.bashrc
5. preserve existing login-only Conda behavior during this refactor, if necessary
```

Do not add `cd`.

Do not source `.bashrc` again from the deployed stub after the tracked dispatcher already does it.

The goal is "thin and purposeful", not "two lines at any cost". The early bootstrap is justified because it is a prerequisite for safely sourcing the layers below it.

---

# Proposed `.bashrc`

`.bashrc` remains the interactive Bash entry point.

Preserve its load-bearing interactive guard:

```sh
case $- in
  *i*) ;;
  *) return ;;
esac
```

For interactive Bash, sequence should be approximately:

```text
1. Bash bootstrap
2. portable environment layer
3. bashrc-common
4. platform-specific bashrc-windows / bashrc-ubuntu
5. project-history hook
6. PATH dedupe/export
7. prompt
```

This ensures a non-login Bash receives the same portable environment policy without requiring it to pretend it is a login shell or directly source `.profile` for interaction semantics.

Existing settings such as `qv` should not be accidentally deleted merely because they are not part of portable environment policy. Preserve existing behavior unless there is a separate reason to change it.

---

# Conda Policy for This Refactor

Do not redesign Conda startup in the same change.

Claude reasonably questioned eager Conda initialization, but that is a separate behavioral decision.

Preserve existing Conda behavior as closely as practical while restructuring startup ordering. Once the shell architecture is stable and tested, Conda can be reconsidered independently.

---

# Repository Line-Ending Policy

Add repository-level `.gitattributes` so shell startup correctness does not depend on global Git configuration.

At minimum, shell scripts and extensionless tracked shell startup files should be normalized to LF.

The exact patterns should be reviewed, but the policy should cover files such as:

```text
*.sh
profile
bash/*
sh/*
real/.bash_profile
real/.bashrc
real/.profile
```

Normalize any currently tracked CRLF shell files as part of this work or an immediately preceding focused commit.

`igncr` remains useful defensive compatibility for Git Bash, but LF should be the repository invariant.

---

# Test Requirements

The existing validator has useful coverage but currently over-relies on manually sourcing implementation files.

## Real Bash login test

Add a behavioral test that invokes Bash's actual login mechanism through temporary deployed stubs.

It must verify:

- startup begins in a chosen project directory,
- `bash --login` does not change `PWD`,
- `.bash_profile` is selected by Bash rather than manually sourced by the test,
- the deployed `real/.bash_profile` path participates,
- `.profile` and `.bashrc` are reached through the real chain.

The exact invocation may use `-c` rather than a human terminal as long as Bash's real login-file selection is exercised.

## WSL wrong-HOME test

Simulate the supported WSL case where initial HOME looks like a Windows path.

Use separate temporary Windows-home and Linux-home locations if necessary so the deployed stub can bootstrap to the Linux dotfiles checkout.

Assert after the real login chain:

```text
HOME = Linux home
ENV = Linux-home/dotfiles/sh/shrc
HISTFILE = Linux-home/.bash_history
portable PATH entries use Linux home
no environment values retain the initial Windows home
PWD is preserved
```

Restore the ENV assertions removed by the current branch.

## Non-login Bash test

Start a fresh interactive non-login Bash and assert it receives the same portable environment policy:

```text
HOME/bin
HOME/dotfiles/bin
ENV
```

while still preserving existing Bash interactive behavior.

## Ordering checks

Do not rely only on grepping for the presence of `set -o igncr`.

Behavior or structural validation should guarantee that Windows CRLF tolerance is active before any vulnerable sourced startup files.

## Existing validations

Continue validating:

- Windows Git Bash behavior,
- Ubuntu/WSL behavior,
- platform isolation,
- terminal-title behavior,
- project history,
- deployment stubs,
- shell syntax.

Codex reported that the Git Bash shell/terminal/project-history validators passed on the current branch while both Ubuntu validators failed. Those Ubuntu failures are blockers.

An unrelated Git-config validator was already failing on master; do not confuse that pre-existing failure with this shell refactor.

Also fix `git show --check` whitespace errors in the branch before merge.

---

# Live-vs-Tracked Stub Drift

A manual diff found:

```text
~/.profile == real/.profile
```

Live `~/.bash_profile` has one extra line:

```sh
[[ -f ~/.bashrc ]] && source ~/.bashrc
```

Do not preserve that line. Under the proposed tracked dispatcher it would source `.bashrc` twice.

Live `~/.bashrc` has one extra `.bash_secrets` source line.

Secrets handling is explicitly deferred for this refactor. Do not let it expand the current scope.

Because `deploy.sh` overwrites the live stubs, do not deploy the current branch until the startup architecture is corrected and validated.

---

# Recommended Implementation Sequence

1. Keep working on `fix/shell-startup-restructure`; do not merge `46b1287` as-is.
2. Preserve the removal of the unconditional `cd`.
3. Remove the committed debug `echo`.
4. Add repository LF policy and normalize shell startup files.
5. Factor/reuse early Bash bootstrap:
   - `igncr` before vulnerable Windows sourcing,
   - WSL HOME repair before HOME-derived environment.
6. Create/refine one idempotent POSIX portable-environment layer.
7. Make `.profile` use that portable environment layer.
8. Make non-login `.bashrc` run Bash bootstrap and then the same portable environment layer.
9. Keep `.bash_profile` as the small Bash login bootstrap/dispatcher that reaches `.profile` and `.bashrc` in the correct order.
10. Preserve Conda behavior rather than redesigning it here.
11. Preserve unrelated existing Bash behavior such as `qv` rather than accidentally dropping it.
12. Remove locale forcing and MANPATH/INFOPATH changes from this refactor.
13. Replace the pseudo-login probe with a genuine Bash login-chain test through deployed stubs.
14. Restore/strengthen WSL wrong-HOME assertions.
15. Add non-login Bash environment coverage.
16. Run Git Bash and both Ubuntu validators.
17. Run `git show --check` and fix whitespace introduced by the branch.
18. Update README/startup documentation to exactly match the final tested chain.
19. Only then consider merge to `master`.

---

# Proposed Invariants

Reviewers should judge the implementation primarily against these invariants:

1. **Startup never changes `PWD` unless the caller explicitly requests it.**
2. **HOME is correct before HOME-derived environment is computed.**
3. **Git Bash CRLF protection is active before vulnerable startup files are sourced.**
4. **Portable environment policy has one implementation and is idempotent.**
5. **Login and non-login interactive Bash receive the same portable environment policy.**
6. **`.profile` remains POSIX-sh-compatible.**
7. **Bash-only interaction remains out of `.profile`.**
8. **Platform-specific toolchains remain out of portable environment policy.**
9. **Inherited locale is preserved unless a separately justified policy changes it.**
10. **Tests exercise real Bash startup selection, not only manual sourcing of implementation files.**
11. **WSL imported-Windows-HOME recovery remains covered behavior.**
12. **The current refactor does not opportunistically redesign Conda, secrets, Git config, or unrelated dotfiles behavior.**

---

# Questions for Reviewers

Please challenge the proposal on these points in particular:

1. Is a shared Bash bootstrap layer the cleanest way to make early `igncr` and WSL HOME repair available to both `.bash_profile` and `.bashrc`?
2. Is a shared POSIX portable-environment layer preferable to having `.bashrc` source `.profile` directly for non-login Bash?
3. Should `ENV="$HOME/dotfiles/sh/shrc"` remain part of portable environment policy, or is there a cleaner plain-sh arrangement?
4. Is preserving current Windows Conda login behavior during this refactor the right scope boundary?
5. Should plain `sh` under WSL be required to recover from an initially wrong Windows HOME, or is that outside the currently supported contract?
6. What is the minimal real-login-shell test matrix needed across Git Bash, Ubuntu-24.04, and the older Ubuntu distro?
7. Are there any startup modes (`ssh host cmd`, `bash -lc`, scripts, subshells, terminal launchers) that this proposal still mishandles?
8. Can the responsibility model be simplified further without reintroducing ordering bugs or login/non-login divergence?

The desired outcome is not merely passing the existing tests. The desired outcome is a startup model whose ordering is explicit enough that the next launcher change does not require another archaeological expedition through six shell files.