# Shell Startup Restructuring Proposal V3

## Status

**Design proposal for review. Do not merge the current implementation yet.**

This V3 supersedes the bootstrap-twice portion of V2. It incorporates the subsequent review discussion and deliberately simplifies the model.

The central idea is now:

> Bootstrap once for a Bash login, establish the portable environment once, then configure the interactive shell.

The design no longer requires `bootstrap` to be idempotent merely because the startup graph intentionally calls it twice.

---

# Scope

Keep this change narrowly about shell startup semantics.

In scope:

- preserving the launcher's selected working directory,
- Bash login startup,
- ordinary Bash non-login interactive startup,
- portable login environment,
- WSL imported-Windows-`HOME` recovery for Bash login,
- LF-only policy for repository-controlled startup files,
- real login-shell tests,
- README/startup documentation.

Explicitly deferred:

- `.bash_secrets`,
- API keys,
- Conda redesign,
- Git configuration cleanup,
- unrelated dotfiles cleanup,
- full zsh/macOS support,
- special recovery for arbitrary non-login Bash shells launched with an independently corrupted `HOME`.

---

# Root Bug

Windows Terminal correctly launches Git Bash in the selected project directory.

The login shell then runs the tracked Bash login implementation, whose old unconditional bare `cd` changes the working directory to `$HOME`.

Therefore:

- the launcher was not fundamentally wrong,
- login startup must never change the caller-selected working directory,
- removing the bare `cd` is required,
- the real login chain must be tested behaviorally.

---

# Revised Responsibility Model

## 1. `.bash_profile`: Bash login bootstrap and dispatch

For a Bash login shell:

```text
~/.bash_profile
    -> establish safe/correct login context once
    -> source ~/.profile
    -> source ~/.bashrc when appropriate
```

Responsibilities:

- repair imported Windows-looking `HOME` under WSL before using `$HOME` to locate later startup files,
- preserve the caller-selected `PWD`,
- source the portable environment through `.profile`,
- dispatch to `.bashrc` for interactive Bash behavior.

It must not:

- perform a bare `cd`,
- print startup diagnostics,
- contain ordinary aliases/functions/history/prompt logic,
- manufacture locale values.

## 2. `.profile`: portable environment

`.profile` owns portable environment policy that should be available to login shells regardless of interactive Bash behavior.

Candidate responsibilities:

- portable `PATH` additions such as `$HOME/bin` and `$HOME/dotfiles/bin`,
- `ENV` for plain `sh`,
- other genuinely portable exported variables that belong to the login environment.

Requirements:

- POSIX `sh` syntax only,
- no Bashisms,
- no output,
- preserve inherited `LANG` rather than inventing a locale,
- no unnecessary `MANPATH`/`INFOPATH` manipulation unless a demonstrated use case requires it.

## 3. `.bashrc`: interactive Bash behavior

`.bashrc` should contain interactive Bash behavior only.

Responsibilities include:

- aliases,
- functions,
- history,
- prompt,
- terminal titles,
- platform-specific interactive setup,
- Java/Gradle/Windows/Ubuntu interactive behavior already intentionally supported.

It should not be required to repair a bad inherited `HOME` in the ordinary design.

## 4. Non-login interactive Bash

An ordinary non-login Bash:

```text
correct parent environment
    -> bash
    -> ~/.bashrc
```

inherits `HOME`, `PATH`, `ENV`, and other environment variables from its parent.

We explicitly do **not** contort `.bashrc` into reconstructing the entire login environment for the hypothetical case where some external program launches `bash -i` with an independently corrupted `HOME`.

If a real use case later demonstrates that requirement, solve that case deliberately rather than making every Bash startup pay for it now.

---

# CRLF / `igncr` Policy

The new preference is to remove `igncr` from the architecture for repository-controlled startup files.

Instead, make LF-only startup files an invariant.

## Repository policy

Add or retain `.gitattributes` rules that force LF for shell startup/configuration files.

Then normalize existing tracked files, not merely future checkouts.

For example, after reviewing the scope:

```sh
git add --renormalize .
git diff --cached --check
```

Do not assume `.gitattributes` retroactively rewrites already-CRLF tracked content.

## Test policy

The validator should fail if any repository-controlled startup file contains CR bytes.

Conceptually:

```text
tracked startup file contains CR
    -> validation failure
    -> do not deploy
```

This is preferable to permanently enabling `igncr` to tolerate files we control.

External files sourced outside the repository, such as installed Conda scripts, are a separate concern and should be handled individually only if they actually present a problem.

---

# WSL `HOME` Ordering

This remains the critical ordering constraint.

If WSL starts Bash with something like:

```text
HOME=/mnt/c/Users/ray
```

then Bash login bootstrap must repair that before doing:

```sh
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
```

Otherwise `.profile` may not even be found, and any `HOME`-derived environment values will be wrong.

Therefore the Bash login sequence is:

```text
bash --login
    -> deployed ~/.bash_profile stub
    -> tracked Bash login implementation
    -> repair WSL HOME if necessary
    -> source correct ~/.profile
    -> source correct ~/.bashrc for interactive Bash
```

This repair is a Bash-login bootstrap concern, not portable `.profile` environment policy.

---

# Startup Silence

All startup files must be silent unless the user explicitly runs an interactive command that is supposed to print something.

No debug `echo` statements belong in `.profile`, `.bash_profile`, bootstrap logic, or other startup files.

This is not merely cosmetic. Unexpected stdout can corrupt non-interactive channels such as remote commands, file-transfer protocols, or tools that expect clean command output.

---

# Locale Policy

Do not run platform-specific `locale -uU` logic and do not invent `en_US.UTF-8` as a fallback.

Preserve the inherited locale supplied by the operating system/login environment unless a real requirement proves otherwise.

The repository should not claim a locale exists when the host has not installed it.

---

# `MANPATH` / `INFOPATH`

Do not migrate these merely because old code mentioned them.

The old variables were effectively dead because they were not exported. The attempted migration introduced incorrect default-path semantics and duplicate entries.

Preferred V3 decision:

- remove them for now,
- reintroduce only if there is a demonstrated private man/info use case,
- if reintroduced, preserve system default search behavior correctly and test repeated sourcing.

---

# Real Login Test: Merge Gate

The most important test must exercise Bash's real login-file selection through deployed-style stubs.

It must not substitute manual sourcing for actual login behavior.

In particular, the test must **not** use:

```text
bash --noprofile --norc
```

and then manually source `bash/bash_profile`.

That pattern is exactly why the original bare-`cd` bug escaped behavioral testing.

The real-login test should create a temporary deployed home containing the appropriate `real/` startup stubs, start from a project directory, launch a genuine Bash login shell, and assert the resulting state.

For the normal Git Bash-style case, assert at least:

```text
PWD   = original project directory
HOME  = expected home
ENV   = expected value
PATH  = correct contents and precedence
stdout from startup = empty
```

For the WSL imported-Windows-HOME case, the same real login path must prove:

```text
HOME -> corrected Linux home
ENV  -> derived from corrected Linux home
PATH -> derived from corrected Linux home, with correct ordering
PWD  -> unchanged project directory
startup stdout -> empty
```

Restoring old direct-`.bashrc` assertions is useful for component coverage, but it is not a substitute for these real-login assertions because the regression occurs in the ordering before `.bashrc` is reached.

---

# PATH Testing

Do not merely assert that expected directories occur somewhere in `PATH`.

Also test precedence/order where it matters.

Example invariant:

```text
$HOME/bin and $HOME/dotfiles/bin appear exactly where policy says they should,
and login vs inherited non-login behavior does not cause a different executable to win unexpectedly.
```

Membership-only tests can pass while behavior changes.

---

# Plain `sh` and macOS

`.profile` should remain POSIX-compatible so it can serve plain `sh` and future shells.

V3 does **not** attempt to repair imported Windows `HOME` for arbitrary plain-`sh` startup under WSL. That is an explicit scope decision, not an accidental omission.

LF-only files are portable to macOS.

If macOS support is needed later, modern macOS defaults to zsh. A likely future adapter would be:

```text
.zprofile -> shared portable environment
.zshrc    -> zsh interactive behavior
```

Keeping `.profile` shell-neutral now makes that easier later.

---

# Live vs Tracked Startup Files

A live-vs-tracked comparison found only two extra local lines:

```text
~/.bash_profile -> manually sources ~/.bashrc again
~/.bashrc       -> manually sources ~/.bash_secrets
```

V3 decisions:

- do not preserve the extra live `.bash_profile` line; the tracked login dispatcher should own `.bashrc` dispatch,
- defer `.bash_secrets` completely for this refactor,
- do not broaden this work into API-key or secret-management cleanup.

---

# Proposed Startup Graph

## Bash login, interactive

```text
Windows Terminal / terminal launcher
    -> bash --login -i
    -> ~/.bash_profile (deployed stub)
    -> tracked Bash login implementation
        -> repair WSL HOME if necessary
        -> ~/.profile
            -> portable environment
        -> ~/.bashrc
            -> interactive Bash configuration
```

## Bash login, non-interactive

```text
bash --login -c command
    -> ~/.bash_profile
    -> login bootstrap
    -> ~/.profile
    -> no unwanted output
    -> command
```

Interactive `.bashrc` behavior must remain guarded by Bash's interactive state.

## Bash non-login, interactive

```text
parent process with correct inherited login environment
    -> bash -i
    -> ~/.bashrc
    -> interactive Bash configuration
```

No duplicate login bootstrap is required.

---

# Required Invariants

Before merge, the design and tests should establish these properties:

1. No login startup file changes the caller-selected `PWD`.
2. Repository-controlled shell startup files are LF-only.
3. No startup file emits unsolicited stdout.
4. Bash login repairs imported Windows `HOME` under WSL before `$HOME` is used to locate `.profile` or derive environment paths.
5. Portable environment policy is established once on the login path.
6. Ordinary non-login Bash inherits the already-correct login environment and only performs interactive Bash setup.
7. `.profile` remains POSIX `sh` compatible.
8. `LANG` is preserved rather than fabricated.
9. `MANPATH`/`INFOPATH` are absent unless a demonstrated requirement justifies them.
10. `PATH` tests verify ordering/precedence as well as membership.
11. The real login validator uses actual `bash --login` startup-file selection through deployed-style stubs.
12. The WSL wrong-`HOME` regression is asserted through that same real login path.
13. Git Bash and Ubuntu validators pass before merge.
14. `git diff --check` / `git show --check` are clean.
15. Conda behavior is preserved rather than redesigned during this refactor.
16. Secret handling remains outside this refactor.

---

# Suggested Implementation Order

1. Preserve the current branch/work before changing direction again.
2. Remove any remaining unconditional `cd` from login startup.
3. Simplify the Bash login implementation to perform WSL `HOME` bootstrap once, then source `.profile` and `.bashrc`.
4. Remove duplicate bootstrap calls from `.bashrc` if introduced by V2 work.
5. Keep `.profile` portable and quiet; move portable environment policy there.
6. Keep `.bashrc` focused on interactive Bash behavior.
7. Remove `igncr` for repository-controlled startup files.
8. Add/verify `.gitattributes` LF rules and actually renormalize existing shell startup files.
9. Remove locale manufacturing and `MANPATH`/`INFOPATH` migration.
10. Replace fake login probes with genuine `bash --login` tests through deployed-style stubs.
11. Add wrong-`HOME`, PWD, silence, ENV, and PATH-order assertions to the real login tests.
12. Run Git Bash validators.
13. Run Ubuntu/WSL validators.
14. Verify `git diff --check` / `git show --check` clean.
15. Review the final branch against these invariants before merge.

---

# Questions for Reviewers

Please attack these decisions specifically rather than re-litigating unrelated dotfiles policy:

1. Is one Bash-login bootstrap sufficient for the actual supported launch paths?
2. Is there a concrete reason an arbitrary non-login interactive Bash must repair an independently corrupted `HOME` instead of inheriting the correct parent environment?
3. Is removing `igncr` safe once LF-only tracked startup files are enforced and tested?
4. Are there repository-controlled startup/config files missing from the proposed LF invariant?
5. Does the real login test truly exercise Bash's own login-file selection and deployed stubs?
6. Does the WSL wrong-`HOME` test prove correction occurs before `.profile` lookup and environment derivation?
7. Is `PATH` precedence identical to the intended policy, not merely membership-equivalent?
8. Are any commands left in `.profile` that are not portable POSIX `sh`?
9. Is preserving inherited locale sufficient on Git Bash and Ubuntu?
10. Is plain-`sh` WSL wrong-`HOME` support actually needed now, or is deferring it reasonable?
11. Are any non-interactive login paths still capable of printing startup output?
12. Does any implementation detail reintroduce duplicate login/bootstrap work that V3 intentionally removes?

---

# Bottom Line

The V3 target is deliberately smaller than V2:

```text
Bash login
    -> bootstrap once
    -> portable .profile once
    -> interactive .bashrc when applicable
```

Repository-controlled CRLF is forbidden rather than tolerated.

Ordinary non-login Bash inherits the correct login environment rather than reconstructing it.

The merge gate is a real `bash --login` test through deployed-style stubs proving that `PWD`, corrected `HOME`, `ENV`, `PATH` precedence, and startup silence are all correct on the actual startup path.
