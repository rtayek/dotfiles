# Shell Startup Restructuring — Reviewer Response to Proposal V2

## Status

**Review of `shell-startup-restructure-proposal-v2.md`. Do not merge `46b1287` yet.**

This handoff is the second-reviewer response the V2 proposal explicitly asked for.
It records what was verified against the live branch, three decisions to lock before
implementation, direct answers to the eight V2 review questions, and concrete artifacts
(root `.gitattributes`, a corrected layer split) to produce.

**Verdict:** the V2 proposal is accurate and sound. Every blocker it lists is real and
reproducible in the branch code. The responsibility model is the right target. The only
substantive changes are (a) the altitude of HOME-repair, (b) the weighting of the `igncr`
blocker, and (c) under-specified deletions in the test section.

Reviewed branch: `fix/shell-startup-restructure`
Reviewed commit: `46b1287f2080e2f84e2164c91e04408c9fafa532`

---

# What Was Verified

Every V2 claim below was checked against the actual files on the branch, not inferred.

| V2 blocker | Status | Evidence in the branch |
|---|---|---|
| 1. WSL HOME repair too late | CONFIRMED | `bash/bash_profile:1-2` sources `.profile` then `.bashrc`; `ray_fix_ubuntu_home` only runs in `bash/bashrc:59-78`. So `profile:8-24` derives `$HOME/bin`, `dotfiles/bin`, `ENV` from the wrong HOME before repair. |
| 2. Login test is not a login test | CONFIRMED | `tests/validate-shell-startup.sh:66-68` runs `bash --noprofile --norc -i -c` then manually `. bash_profile`. Bypasses Bash's login-file selection and the deployed `real/.bash_profile` stub. |
| 3. `igncr` runs too late | CONFIRMED (re-weight, see below) | `bash/bashrc-windows:2`, sourced at `bash/bashrc:82-85`, after `bashrc-common`/aliases/functions and, in the login path, after `.profile`. |
| 4. Debug output committed | CONFIRMED | `profile:1` -> `echo "EXECUTING PROFILE. HOME=$HOME"`. |
| 5. Fragile locale handling | CONFIRMED | `profile:2-6` uses non-portable `locale -uU` with an `en_US.UTF-8` fallback. |
| 6. MANPATH / INFOPATH migration | CONFIRMED | `profile:20-22` now exports both. |
| 7. Non-login Bash divergence | CONFIRMED | `bashrc-common` no longer sets `$HOME/bin`, `dotfiles/bin`, or `ENV`; they live only in `profile`, and `bash/bashrc` never sources `profile`. A fresh non-login interactive Bash loses them. |

Supporting claims, also verified:

- **No repository `.gitattributes`.** LF normalization currently leaks in only through a
  machine-global setting: `core.attributesFile = ~/dotfiles/git/gitattributes`, set in
  `git/gitconfig-common`. This is exactly the machine-global dependency V2 warns about. A
  fresh clone on a machine that has not deployed Ray's global Git config gets no
  normalization.
- **CRLF already exists in tracked shell material.** `sh/shrc` is CRLF in the working tree
  right now (`git ls-files --eol` reports `i/lf w/crlf`, and `file` reports
  "CRLF line terminators"). This is a live instance of the exact hazard `igncr`/LF policy
  is meant to remove.
- **Whitespace error is real.** `git diff --check master...HEAD` flags
  `tests/validate-shell-startup.sh:61: trailing whitespace` (the blank line inside
  `run_login_probe`).

---

# Decisions to Lock Before Implementing

These are the three things a reviewer should settle so the next implementation pass does
not need another round trip.

## Decision 1 — HOME-repair belongs in the portable-environment layer, not a Bash-only bootstrap

V2 bundles `igncr` + WSL HOME-repair into one "Bash bootstrap" run from `.bash_profile`
and `.bashrc`. But V2's own invariant #2 says "HOME is correct before HOME-derived
environment is computed." That cannot be a Bash-only guarantee, because the portable-env
layer derives from HOME and plain `sh` login reaches it through `.profile` with no Bash
bootstrap. A wrong WSL HOME therefore leaves plain-sh environment wrong — the same
login/non-login asymmetry the refactor is trying to remove, in a different shell.

Resolution: split the bootstrap.

- `igncr` is genuinely Bash + Windows only. It stays a Bash bootstrap concern.
- HOME-repair is a **prerequisite of the portable-env layer**. Move a POSIX-safe,
  idempotent form of it into (or immediately ahead of) that layer, so both `.profile`
  (plain sh) and the Bash path get a correct HOME before deriving any path.

This also answers V2's open Q5 instead of leaving it hanging: plain sh under WSL recovers
"for free" because recovery lives in the shared layer both shells use.

If the team instead decides plain-sh WSL recovery is out of contract, then invariant #2
must be explicitly rescoped to "for Bash startup," because otherwise the document promises
a guarantee the design does not provide.

## Decision 2 — Repository `.gitattributes` is the primary CRLF fix; `igncr` is secondary

Once a repo-level `.gitattributes` pins shell files to LF on checkout, tracked sourced
files cannot be CRLF, and `igncr`-timing becomes defense-in-depth rather than a load-
bearing blocker. Two facts reinforce this:

1. The truly-earliest file Bash reads is the deployed `real/.bash_profile` stub. `igncr`
   set *inside* the tracked `bash_profile` cannot retroactively protect the stub that
   sourced it. Only LF-on-checkout protects the stub.
2. `sh/shrc` is CRLF in the working tree today despite the global attributes file, because
   normalization depends on machine-global config that a clean checkout may not have.

Resolution: treat blocker #3 as **down-ranked**. Keep an early `igncr` for Git Bash muscle
memory, but do not contort the bootstrap architecture around its ordering. This is the
concrete simplification V2's Q8 asks for.

## Decision 3 — The test rework must delete assertions, not only add them

V2 lists new tests but omits the deletions its own policy changes force. Removing
locale-forcing (#5) and MANPATH/INFOPATH (#6) means the current hard assertions must be
removed or inverted, or the corrected branch fails its own suite:

- `tests/validate-shell-startup.sh:334-335` and `:343-344` assert `MANPATH=...` /
  `INFOPATH=...`.
- `tests/validate-shell-startup.sh:337` and `:346` assert `LANG=en_US.UTF-8`.

Also add one test V2 mandates in spirit but never specifies: **idempotency**. The login
path now sources the env layer twice (once via `.profile`, once via `.bashrc`). Source it
twice in a probe and assert exactly one `$HOME/bin` entry in PATH. Invariant #4 is asserted
but currently untested.

---

# Smaller Notes

- **Non-interactive Bash is undefined.** `ssh host cmd`, `bash -c`, and scripts read
  neither `.profile` nor `.bashrc` (only `$BASH_ENV`), so they receive none of the portable
  env. V2 raises this in Q7 but leaves it open. Give it a definitive answer: declare
  non-interactive shells out of scope and document it, or accept that `~/bin` tools are
  unavailable over `ssh host cmd`. Do not paper over it with `BASH_ENV`, which introduces a
  separate class of surprises.
- **Idempotency guard strategy.** Achieve idempotency by construction (PATH membership
  tests such as `case ":$PATH:" in *":$HOME/bin:"*)`), not with an exported run-once guard
  variable. Exported guards leak into subshells and then wrongly *skip* re-initialization
  when it is legitimately needed.
- **`qv` placement.** The branch preserved `qv` by moving it into `profile:25`, i.e. into
  the very "portable environment" file V2 says must stay minimal and truly portable.
  `qv="//sdcard/Download/videos"` is neither. Decide: document it as a deliberate exception,
  or move it to `bashrc-common`. V2 says both "preserve `qv`" and "keep the env layer
  minimal" without resolving where it lands.
- **Naming.** V2 invites feedback on layer names. `sh/environment` (next to `sh/shrc`) and
  `bash/bootstrap` match the repo's existing `sh/` and `bash/` directories better than a new
  top-level `shell/` directory.

---

# Corrected Layer Model

The only structural change from V2 is that HOME-repair moves down into the shared
environment layer, leaving `igncr` as the sole Bash-bootstrap concern.

```
shared portable environment (POSIX, idempotent, no cd)
  - repair imported Windows HOME (moved here from bashrc)
  - add $HOME/bin, $HOME/dotfiles/bin to PATH if present
  - export PATH
  - ENV=$HOME/dotfiles/sh/shrc
        ^                         ^                         ^
        |                         |                         |
   .profile                   .bashrc                  plain sh login
   (bash login via            (login: 2nd, idempotent   reads .profile only
    .bash_profile,             pass; non-login: 1st pass)
    and plain sh)                   |
        |                     bash bootstrap (bash+win only)
   bash bootstrap             - igncr before vulnerable sourcing
   (bash+win only)                  |
   - igncr                    bashrc-common -> platform -> project-history
   (HOME already                   -> dedupe PATH -> prompt
    correct via env layer)

bash login flow:
  .bash_profile
    -> bash bootstrap (igncr)
    -> .profile -> env layer (HOME-repair, PATH, ENV)
    -> .bashrc  -> bash bootstrap (idempotent) -> env layer (idempotent)
               -> bashrc-common -> platform -> project-history -> prompt

non-login interactive bash:
  .bashrc -> bash bootstrap -> env layer -> bashrc-common -> platform -> prompt

plain sh login:
  .profile -> env layer (HOME-repair, PATH, ENV) -> ENV points interactive sh at sh/shrc
```

Invariant to preserve: HOME-repair and the env layer are both safe to run more than once,
so the double pass in login Bash produces no duplicate PATH entries and no wrong-HOME
derivation.

---

# Concrete Artifact — Draft Repository `.gitattributes`

Place at repo root. Patterns need a final review, but this is the intended shape. The point
is that startup correctness stops depending on `core.attributesFile`.

```gitattributes
# Normalize to LF in the repo; check out LF everywhere by default.
* text=auto eol=lf

# Shell startup + scripts: force LF regardless of content detection.
*.sh                   text eol=lf
profile                text eol=lf
sh/*                   text eol=lf
bash/*                 text eol=lf
real/.bash_profile     text eol=lf
real/.bashrc           text eol=lf
real/.profile          text eol=lf
real/.bash_aliases     text eol=lf
real/.bash_functions*  text eol=lf

# Windows-native command files keep CRLF.
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf
```

After adding it, renormalize and commit the result in a focused commit:

```sh
git add --renormalize .
git status   # expect sh/shrc (currently CRLF in the working tree) to normalize to LF
git commit -m "Normalize shell startup files to LF via repository .gitattributes"
```

`sh/shrc` is the known live offender; confirm it and any other shell file land as LF.

---

# Answers to the V2 "Questions for Reviewers"

1. **Shared Bash bootstrap for early `igncr` + HOME repair?** Partially. Split it. `igncr`
   is Bash+Windows bootstrap. HOME-repair is a portable-env prerequisite that plain sh also
   needs. One bundle re-creates the asymmetry the refactor is removing. (See Decision 1.)
2. **Shared POSIX env layer vs `.bashrc` sourcing `.profile` directly?** Prefer the shared
   layer. Having `.bashrc` source `.profile` drags plain-sh prompt logic and the
   `BASH_VERSION` return guard into interactive Bash and couples the two entry points. A
   standalone idempotent env file sourced by both is cleaner.
3. **Keep `ENV="$HOME/dotfiles/sh/shrc"` in env policy?** Yes. `ENV` is the POSIX
   interactive-sh entry mechanism; it is environment policy, not Bash interaction. It
   belongs in the env layer.
4. **Preserve Windows Conda login behavior as the scope boundary?** Yes, defer Conda. Note
   that current Conda init lives in `bashrc-windows` (the interactive path), so "login Conda
   behavior" is already effectively "interactive-Bash Conda behavior." Preserve as-is and
   flag it for a separate pass.
5. **Should plain sh under WSL recover from a wrong Windows HOME?** Yes, and it becomes free
   if HOME-repair moves into the shared env layer (Decision 1). If the team says no, rescope
   invariant #2 to "for Bash" so the document does not imply a guarantee it does not deliver.
6. **Minimal real-login test matrix?** Three shapes — login, non-login interactive, and
   wrong-HOME — each driven through the real deployed stub chain (not manual sourcing), on
   Git Bash and Ubuntu-24.04. The older Ubuntu distro needs only a wrong-HOME + login smoke
   test; if it is slated for removal (see `working-context.md` open questions), do not over-
   invest there.
7. **Startup modes still mishandled?** Non-interactive Bash (`ssh host cmd`, `bash -c`,
   scripts) reads neither startup file and receives no portable env. `bash -lc` is covered
   (login). Subshells inherit exported env and are fine. Resolve the non-interactive case
   explicitly (see Smaller Notes).
8. **Can the model be simplified further?** Yes. Once `.gitattributes` enforces LF,
   `igncr`-ordering stops being load-bearing, and HOME-repair moves into the env layer. The
   remaining "bootstrap" shrinks to a single Windows-guarded `igncr` line, removing a whole
   conceptual layer from the graph.

---

# Delta to the V2 Implementation Sequence

Keep V2's 19-step sequence, with these adjustments:

- **Reorder:** do the `.gitattributes` + renormalize commit *first* (V2 step 4 becomes step
  1), since it is the primary CRLF fix and the rest should be authored on already-normalized
  files.
- **Step 5 (bootstrap):** implement only `igncr` here. Move WSL HOME-repair into the env
  layer built in step 6.
- **Step 6 (env layer):** include the POSIX-safe idempotent HOME-repair at the top of this
  layer, before PATH/ENV derivation.
- **Steps 13-15 (tests):** in addition to the new real-login and non-login tests, delete the
  `MANPATH`/`INFOPATH`/`LANG` assertions at `tests/validate-shell-startup.sh:334-346` and add
  a source-twice idempotency assertion.
- **Also:** fix the `tests/validate-shell-startup.sh:61` trailing-whitespace before merge
  (V2 already calls for `git show --check`/`git diff --check` to be clean).

---

# Invariants — Amended

Adopt V2's twelve invariants, with #2 sharpened so it is not silently Bash-only:

> **2. HOME is correct before any shell derives HOME-based environment — for both Bash and
> plain sh — because HOME-repair lives in the shared portable-environment layer, not in a
> Bash-only bootstrap.**

Everything else in the V2 invariant list stands.

---

# Do Not

- Do not merge `46b1287` as-is.
- Do not run `deploy.sh` from this branch into a real `$HOME` until the architecture is
  corrected and validated; it overwrites the live stubs, and the live `~/.bashrc`
  `.bash_secrets` hook plus the extra `~/.bash_profile` source line are deferred concerns
  that must not be clobbered mid-refactor. (The test harness deploys only into a temp home,
  which is safe.)
- Do not expand scope into secrets, Conda redesign, Git-config failures, or unrelated
  dotfiles cleanup.
