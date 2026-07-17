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

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "$3" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "$3" ;;
  esac
}

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

run_startup_probe() {
  local home_dir=$1
  local uname_s=$2
  local os_id=${3:-}

  HOME="$home_dir" \
  PATH="/usr/bin:/bin" \
  RAY_DOTFILES_UNAME_S="$uname_s" \
  RAY_DOTFILES_OS_ID="$os_id" \
  bash --noprofile --norc -i -c "
    . '$repo_root/bash/bashrc' >/dev/null
    printf 'PS1=%s\n' \"\$PS1\"
    printf 'PATH=%s\n' \"\$PATH\"
    printf 'JAVA_HOME=%s\n' \"\${JAVA_HOME-}\"
    printf 'GRADLE_HOME=%s\n' \"\${GRADLE_HOME-}\"
    printf 'myroot=%s\n' \"\${myroot-}\"
    printf 'RAY_DEV_HOME=%s\n' \"\${RAY_DEV_HOME-}\"
    printf 'RAY_TEST_UBUNTU_CONDA=%s\n' \"\${RAY_TEST_UBUNTU_CONDA-}\"
    alias gs >/dev/null 2>&1 && printf 'alias_gs=yes\n'
    type pathPrepend >/dev/null 2>&1 && printf 'function_pathPrepend=yes\n'
    type dedupePath >/dev/null 2>&1 && printf 'function_dedupePath=yes\n'
    type gchat >/dev/null 2>&1 && printf 'function_gchat=yes\n'
    printf 'HISTSIZE=%s\n' \"\$HISTSIZE\"
    printf 'HISTFILESIZE=%s\n' \"\$HISTFILESIZE\"
    printf 'HISTCONTROL=%s\n' \"\$HISTCONTROL\"
    printf 'ENV=%s\n' \"\$ENV\"
  " 2>/dev/null
}

syntax_files=(
  "$repo_root/bash/bash_profile"
  "$repo_root/bash/bashrc"
  "$repo_root/bash/bashrc-common"
  "$repo_root/bash/bashrc-windows"
  "$repo_root/bash/bashrc-ubuntu"
  "$repo_root/bash/bashrc-project-history"
  "$repo_root/bash/bash_aliases"
  "$repo_root/bash/bash_functions"
  "$repo_root/bash/bash_functions-windows"
  "$repo_root/bash/bash_functions-ubuntu"
)

for file in "${syntax_files[@]}"; do
  bash -n "$file"
done
sh -n "$repo_root/profile"
sh -n "$repo_root/sh/shrc"
pass "startup files have no shell syntax errors"

for bootstrap in .bash_profile .bashrc .profile .bash_aliases .bash_functions .minttyrc; do
  [ -f "$repo_root/real/$bootstrap" ] || fail "missing real/$bootstrap"
done

grep -Fq '$HOME/dotfiles/bash/bash_profile' "$repo_root/real/.bash_profile" || fail "real/.bash_profile target changed"
grep -Fq '$HOME/dotfiles/bash/bashrc' "$repo_root/real/.bashrc" || fail "real/.bashrc target changed"
grep -Fq '$HOME/dotfiles/profile' "$repo_root/real/.profile" || fail "real/.profile target changed"
grep -Fq 'dotfiles/bash/bash_aliases' "$repo_root/real/.bash_aliases" || fail "real/.bash_aliases target changed"
grep -Fq '$HOME/dotfiles/bash/bash_functions' "$repo_root/real/.bash_functions" || fail "real/.bash_functions target changed"
grep -Fq 'ThemeFile=xterm' "$repo_root/real/.minttyrc" || fail "real/.minttyrc target changed"
pass "bootstrap files still point to intended tracked files"

grep -Fq 'set -o igncr' "$repo_root/bash/bash_profile" || fail "Windows igncr handling missing"
grep -Fq '/c/Users/ray/miniconda3/etc/profile.d/conda.sh' "$repo_root/bash/bash_profile" || fail "Windows Conda path changed"
pass "Windows login-profile igncr and Conda path are preserved"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

linux_home="$tmp_root/linux-home"
windows_home="$tmp_root/windows-home"
make_test_home "$linux_home"
make_test_home "$windows_home"
mkdir -p "$linux_home/bin" "$linux_home/dev" "$linux_home/anaconda3/etc/profile.d"
printf 'export RAY_TEST_UBUNTU_CONDA=loaded\n' >"$linux_home/anaconda3/etc/profile.d/conda.sh"

linux_output="$(run_startup_probe "$linux_home" Linux ubuntu)"
windows_output="$(run_startup_probe "$windows_home" MINGW64_NT-10.0 '')"

assert_contains "$linux_output" "PS1=\\u@\\h \\W \\$ " "Linux final prompt changed"
assert_contains "$windows_output" "PS1=\\u@\\h \\W \\$ " "Windows final prompt changed"
pass "final prompt remains PS1='\\u@\\h \\W \\$ '"

assert_not_contains "$linux_output" "/c/dfromrays8350" "Windows myroot path loaded for Linux"
assert_not_contains "$linux_output" "/c/Gradle/gradle-9.1.0" "Windows Gradle path loaded for Linux"
assert_not_contains "$linux_output" "/c/Program Files/Java/jdk-25" "Windows Java path loaded for Linux"
assert_not_contains "$linux_output" "/c/Users/ray/miniconda3" "Windows Conda path loaded for Linux"
assert_not_contains "$linux_output" "function_gchat=yes" "Windows gchat loaded for Linux"
pass "Windows-only paths and functions are not loaded for Linux"

assert_not_contains "$windows_output" "RAY_DEV_HOME=$windows_home/dev" "Ubuntu dev setting loaded for Git Bash"
assert_not_contains "$windows_output" "RAY_TEST_UBUNTU_CONDA=loaded" "Ubuntu Conda loaded for Git Bash"
pass "Ubuntu-only configuration is not loaded for Git Bash"

assert_contains "$linux_output" "alias_gs=yes" "common aliases did not load for Linux"
assert_contains "$linux_output" "function_pathPrepend=yes" "pathPrepend did not load for Linux"
assert_contains "$linux_output" "function_dedupePath=yes" "dedupePath did not load for Linux"
assert_contains "$windows_output" "alias_gs=yes" "common aliases did not load for Git Bash"
assert_contains "$windows_output" "function_pathPrepend=yes" "pathPrepend did not load for Git Bash"
assert_contains "$windows_output" "function_dedupePath=yes" "dedupePath did not load for Git Bash"
pass "common aliases and functions load on both platforms"

assert_contains "$linux_output" "JAVA_HOME=" "Linux JAVA_HOME unexpectedly required"
assert_contains "$linux_output" "GRADLE_HOME=" "Linux GRADLE_HOME unexpectedly required"
assert_contains "$linux_output" "RAY_TEST_UBUNTU_CONDA=loaded" "Ubuntu Conda guard did not load existing conda.sh"
pass "Ubuntu startup does not require JAVA_HOME or GRADLE_HOME"

assert_contains "$windows_output" "JAVA_HOME=/c/Program Files/Java/jdk-25" "Windows JAVA_HOME changed"
assert_contains "$windows_output" "GRADLE_HOME=/c/Gradle/gradle-9.1.0" "Windows GRADLE_HOME changed"
assert_contains "$windows_output" "myroot=/c/dfromrays8350" "Windows myroot changed"
assert_contains "$windows_output" "/c/dfromrays8350/bin" "Windows myroot/bin missing from PATH"
assert_contains "$windows_output" "/c/Gradle/gradle-9.1.0/bin" "Windows Gradle bin missing from PATH"
assert_contains "$windows_output" "/c/Program Files/Java/jdk-25/bin" "Windows Java bin missing from PATH"
assert_contains "$windows_output" "function_gchat=yes" "Windows gchat function missing"
pass "Windows Java, Gradle, and myroot behavior is preserved"

assert_contains "$windows_output" "HISTSIZE=10000" "HISTSIZE changed"
assert_contains "$windows_output" "HISTFILESIZE=20000" "HISTFILESIZE changed"
assert_contains "$windows_output" "HISTCONTROL=ignoredups:erasedups" "HISTCONTROL changed"
assert_contains "$windows_output" 'ENV='"$windows_home"'/dotfiles/sh/shrc' "ENV changed"
pass "history and ENV settings are preserved"
