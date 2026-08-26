#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

bash -n "$repo_root/direnv/envrc"
bash -n "$repo_root/bash/bashrc-project-history"
pass "project-history shell files have no syntax errors"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

project_root="$tmp/project"
mkdir -p "$project_root/src/deeper"

(
  cd "$project_root"
  # shellcheck disable=SC1091
  source "$repo_root/direnv/envrc"
  useProjectHistory

  expected="$project_root/.bash_history"
  [ "${RAY_PROJECT_HISTORY-}" = "1" ] ||
    fail "useProjectHistory did not enable project history"
  [ "${RAY_PROJECT_HISTORY_FILE-}" = "$expected" ] ||
    fail "useProjectHistory did not anchor history at the directory where it was called"

  cd src/deeper
  [ "${RAY_PROJECT_HISTORY_FILE-}" = "$expected" ] ||
    fail "project history path changed after entering a subdirectory"

  disableProjectHistory
  [ "${RAY_PROJECT_HISTORY-}" = "0" ] ||
    fail "disableProjectHistory did not disable project history"
  [ -z "${RAY_PROJECT_HISTORY_FILE-}" ] ||
    fail "disableProjectHistory left the project history file set"
)
pass "useProjectHistory captures one stable project-root history file"

home="$tmp/home"
mkdir -p "$home"

(
  HOME="$home"
  HISTFILE="$HOME/.bash_history"
  export HOME HISTFILE
  set -o history

  RAY_PROJECT_HISTORY=1
  RAY_PROJECT_HISTORY_FILE="$project_root/.bash_history"
  export RAY_PROJECT_HISTORY RAY_PROJECT_HISTORY_FILE

  ray_update_terminal_title() { :; }

  old_path="$PATH"
  PATH="$tmp/no-direnv"
  # shellcheck disable=SC1091
  source "$repo_root/bash/bashrc-project-history"
  PATH="$old_path"

  cd "$project_root/src/deeper"
  __ray_prompt_command

  [ "$HISTFILE" = "$project_root/.bash_history" ] ||
    fail "prompt command moved project history into a subdirectory"
)
pass "prompt command keeps history anchored while moving through subdirectories"

(
  HOME="$home"
  HISTFILE="$tmp/previous-history"
  export HOME HISTFILE
  set -o history

  RAY_PROJECT_HISTORY=1
  unset RAY_PROJECT_HISTORY_FILE

  ray_update_terminal_title() { :; }

  old_path="$PATH"
  PATH="$tmp/no-direnv"
  # shellcheck disable=SC1091
  source "$repo_root/bash/bashrc-project-history"
  PATH="$old_path"

  __ray_prompt_command

  [ "$HISTFILE" = "$HOME/.bash_history" ] ||
    fail "missing project history path did not fall back to home history"
)
pass "missing project history path safely falls back to home history"

grep -Fxq 'source ~/dotfiles/direnv/envrc' "$repo_root/.envrc" ||
  fail "dotfiles .envrc does not load the shared direnv helper library"
grep -Fxq 'useProjectHistory' "$repo_root/.envrc" ||
  fail "dotfiles .envrc does not opt into project history"
pass "dotfiles .envrc opts into project history explicitly"
