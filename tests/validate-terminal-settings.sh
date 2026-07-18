#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
settings_json="$repo_root/settings.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

node - "$settings_json" <<'NODE'
const fs = require("fs");
const settingsPath = process.argv[2];
const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
const profiles = settings.profiles && Array.isArray(settings.profiles.list)
  ? settings.profiles.list
  : [];

const projects = [
  ["Red", "#3A0000"],
  ["Green", "#003A00"],
  ["Blue", "#00003A"],
  ["Cyan", "#003A3A"],
  ["Magenta", "#3A003A"],
  ["Yellow", "#3A3A00"],
];

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

function findProfile(name) {
  return profiles.find((profile) => profile.name === name);
}

for (const [project, background] of projects) {
  const winProfile = findProfile(project);
  if (!winProfile) fail(`missing Windows Git Bash profile ${project}`);
  if (winProfile.background !== background) fail(`${project} background changed`);
  if (winProfile.commandline !== "bash.exe") fail(`${project} commandline changed`);
  if (winProfile.tabColor !== "#008CCF") fail(`${project} Windows tab color changed`);
  if (winProfile.tabTitle !== "WIN") fail(`${project} Windows fallback tab title changed`);
  if (winProfile.suppressApplicationTitle !== false) fail(`${project} does not allow shell title updates`);

  const wslProfile = findProfile(`WSL ${project}`);
  if (!wslProfile) fail(`missing WSL profile WSL ${project}`);
  if (wslProfile.background !== background) fail(`WSL ${project} background does not match Windows profile`);
  if (wslProfile.commandline !== "wsl.exe -d Ubuntu") fail(`WSL ${project} commandline changed`);
  if (wslProfile.tabColor !== "#FF8C00") fail(`WSL ${project} tab color changed`);
  if (wslProfile.tabTitle !== "WSL") fail(`WSL ${project} fallback tab title changed`);
  if (wslProfile.suppressApplicationTitle !== false) fail(`WSL ${project} does not allow shell title updates`);
}
NODE
pass "Windows Terminal profiles preserve backgrounds, tab colors, and shell-updatable titles"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_test_home() {
  local home_dir=$1
  mkdir -p "$home_dir"
  cat >"$home_dir/.bash_aliases" <<EOF
[ -f "$repo_root/bash/bash_aliases" ] && . "$repo_root/bash/bash_aliases"
EOF
  cat >"$home_dir/.bash_functions" <<EOF
[ -f "$repo_root/bash/bash_functions" ] && . "$repo_root/bash/bash_functions"
EOF
  cat >"$home_dir/.bash_functions-windows" <<EOF
[ -f "$repo_root/bash/bash_functions-windows" ] && . "$repo_root/bash/bash_functions-windows"
EOF
  cat >"$home_dir/.bash_functions-ubuntu" <<EOF
[ -f "$repo_root/bash/bash_functions-ubuntu" ] && . "$repo_root/bash/bash_functions-ubuntu"
EOF
}

capture_title() {
  local home_dir=$1
  local uname_s=$2
  local os_id=$3
  local work_dir=$4

  HOME="$home_dir" \
  PATH="/usr/bin:/bin" \
  WT_SESSION=test-session \
  RAY_DOTFILES_UNAME_S="$uname_s" \
  RAY_DOTFILES_OS_ID="$os_id" \
  bash --noprofile --norc -i -c "
    cd '$work_dir'
    . '$repo_root/bash/bashrc' >/dev/null
    __ray_prompt_command
  " 2>/dev/null | tr '\033\007' '[]'
}

win_home="$tmp_root/win-home"
wsl_home="$tmp_root/wsl-home"
project_dir="$tmp_root/dotfiles"
mkdir -p "$project_dir"
make_test_home "$win_home"
make_test_home "$wsl_home"

win_title="$(capture_title "$win_home" MINGW64_NT-10.0 '' "$project_dir")"
wsl_title="$(capture_title "$wsl_home" Linux ubuntu "$project_dir")"

case "$win_title" in
  *"]0;WIN - dotfiles]"*) ;;
  *) fail "Windows shell title did not use current folder name" ;;
esac

case "$wsl_title" in
  *"]0;WSL - dotfiles]"*) ;;
  *) fail "WSL shell title did not use current folder name" ;;
esac

pass "shell startup sets WIN/WSL titles from the current folder name"
