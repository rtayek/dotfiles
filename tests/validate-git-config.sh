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

common="$repo_root/git/gitconfig-common"
windows="$repo_root/git/gitconfig-windows"
ubuntu="$repo_root/git/gitconfig-ubuntu"
global_ignore="$repo_root/git/gitignore"
root_ignore="$repo_root/.gitignore"

for f in "$common" "$windows" "$ubuntu" "$global_ignore" "$root_ignore"; do
  [ -f "$f" ] || fail "missing file: $f"
done
pass "Git configuration files exist"

git config --file "$common" --list >/dev/null
git config --file "$windows" --list >/dev/null
git config --file "$ubuntu" --list >/dev/null
pass "Git configuration files parse"

if grep -Eq '([A-Za-z]:/|/mnt/[A-Za-z]/|/c/Users/)' "$common"; then
  fail "common Git configuration contains a platform-specific path"
fi
pass "common Git configuration has no Windows-only paths"

grep -Fq 'excludesfile = ~/dotfiles/git/gitignore' "$common" ||
  fail "common Git configuration does not reference the global excludes file"
pass "common Git configuration references git/gitignore"

grep -Fq 'attributesfile = C:/Users/ray/.config/git/attributes' "$windows" ||
  fail "Windows attributesfile setting was not preserved"
grep -Fq 'directory = G:/pt' "$windows" ||
  fail "Windows safe.directory setting was not preserved"
pass "Windows-only Git settings remain in gitconfig-windows"

for pattern in '.project' '.classpath' '.settings/' '.gradle/' 'build/'; do
  if grep -Fxq "$pattern" "$global_ignore"; then
    fail "global Git ignore contains repository-specific rule: $pattern"
  fi
done
pass "global Git ignore does not hide Eclipse or build-system policy"

for pattern in \
  'openclaw.json.tmp' \
  'openclaw.log' \
  'publish-utilities/.gradle/' \
  'publish-utilities/build/'
do
  grep -Fxq "$pattern" "$root_ignore" ||
    fail "dotfiles .gitignore is missing: $pattern"
done
pass "dotfiles .gitignore contains repository-specific generated files"

git -C "$repo_root" ls-files --error-unmatch .envrc >/dev/null 2>&1 ||
  fail ".envrc is not tracked"
grep -Fxq 'source ~/dotfiles/direnv/envrc' "$repo_root/.envrc" ||
  fail ".envrc does not load the shared direnv helper file"
pass ".envrc is tracked reusable configuration"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

linux_home="$tmp/linux-home"
windows_home="$tmp/windows-home"
mkdir -p "$linux_home" "$windows_home"

HOME="$linux_home" USER=ray RAY_DOTFILES_UNAME_S=Linux \
  sh "$repo_root/deploy.sh" >/dev/null
grep -Fq 'path = ~/dotfiles/git/gitconfig-common' "$linux_home/.gitconfig" ||
  fail "Linux deployment did not include common Git config"
grep -Fq 'path = ~/dotfiles/git/gitconfig-ubuntu' "$linux_home/.gitconfig" ||
  fail "Linux deployment did not include Ubuntu Git config"
if grep -Fq 'gitconfig-windows' "$linux_home/.gitconfig"; then
  fail "Linux deployment included Windows Git config"
fi
pass "Linux deployment generates the expected .gitconfig stub"

HOME="$windows_home" USER=ray LOCALAPPDATA="$tmp/no-localappdata" \
  RAY_DOTFILES_UNAME_S=MINGW64_NT \
  sh "$repo_root/deploy.sh" >/dev/null
grep -Fq 'path = ~/dotfiles/git/gitconfig-common' "$windows_home/.gitconfig" ||
  fail "Windows deployment did not include common Git config"
grep -Fq 'path = ~/dotfiles/git/gitconfig-windows' "$windows_home/.gitconfig" ||
  fail "Windows deployment did not include Windows Git config"
if grep -Fq 'gitconfig-ubuntu' "$windows_home/.gitconfig"; then
  fail "Windows deployment included Ubuntu Git config"
fi
pass "Windows deployment generates the expected .gitconfig stub"
