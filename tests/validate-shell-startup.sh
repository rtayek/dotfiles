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

assert_line_equals() {
  printf '%s\n' "$1" | grep -Fxq "$2" || fail "$3"
}

make_test_home() {
  local home_dir=$1
  mkdir -p "$home_dir/man" "$home_dir/info" "$home_dir/bin" "$home_dir/dotfiles/bin"
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
  cat >"$home_dir/.bashrc" <<EOF
[ -f "$repo_root/bash/bashrc" ] && . "$repo_root/bash/bashrc"
EOF
  cat >"$home_dir/.profile" <<EOF
[ -f "$repo_root/profile" ] && . "$repo_root/profile"
EOF
  cat >"$home_dir/.bash_profile" <<EOF
[ -f "$repo_root/bash/bash_profile" ] && . "$repo_root/bash/bash_profile"
EOF
  ln -s "$repo_root/bash" "$home_dir/dotfiles/bash"
  ln -s "$repo_root/sh" "$home_dir/dotfiles/sh"
  ln -s "$repo_root/profile" "$home_dir/dotfiles/profile"
}

run_login_probe() {
  local home_dir=$1
  local uname_s=$2
  local os_id=${3:-}

  mkdir -p "$home_dir/some_project"

  (
    cd "$home_dir/some_project"
    HOME="$home_dir" \
    PATH="/usr/bin:/bin" \
    JAVA_HOME= \
    GRADLE_HOME= \
    myroot= \
    WT_SESSION= \
    RAY_DOTFILES_UNAME_S="$uname_s" \
    RAY_DOTFILES_OS_ID="$os_id" \
    bash --login -i -c "
      printf 'HOME=%s\n' \"\$HOME\"
      printf 'PWD=%s\n' \"\$PWD\"
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
      printf 'HISTFILE=%s\n' \"\$HISTFILE\"
      printf 'HISTSIZE=%s\n' \"\$HISTSIZE\"
      printf 'HISTFILESIZE=%s\n' \"\$HISTFILESIZE\"
      printf 'HISTCONTROL=%s\n' \"\$HISTCONTROL\"
      printf 'ENV=%s\n' \"\$ENV\"
    " 2>/dev/null
  )
}


run_idempotency_probe() {
  local home_dir=$1
  local uname_s=$2
  local os_id=${3:-}

  (
    cd "$home_dir/some_project"
    HOME="$home_dir" \
    PATH="/usr/bin:/bin" \
    RAY_DOTFILES_UNAME_S="$uname_s" \
    RAY_DOTFILES_OS_ID="$os_id" \
    bash --noprofile --norc -i -c "
      . '$home_dir/dotfiles/profile'
      . '$home_dir/dotfiles/profile'
      printf 'PATH=%s\n' \"\$PATH\"
    "
  )
}


run_silence_probe() {
  local home_dir=$1
  local uname_s=$2
  local os_id=${3:-}

  (
    cd "$home_dir/some_project"
    HOME="$home_dir" \
    PATH="/usr/bin:/bin" \
    JAVA_HOME= \
    GRADLE_HOME= \
    myroot= \
    WT_SESSION= \
    RAY_DOTFILES_UNAME_S="$uname_s" \
    RAY_DOTFILES_OS_ID="$os_id" \
    bash --login -i -c "printf 'PROBE_START\n'" 2>&1
  )
}

run_nonlogin_inheritance_probe() {
  local home_dir=$1
  (
    cd "$home_dir/some_project"
    HOME="$home_dir" \
    PATH="/inherited/path:/usr/bin:/bin" \
    ENV="/inherited/env" \
    JAVA_HOME= \
    GRADLE_HOME= \
    myroot= \
    WT_SESSION= \
    RAY_DOTFILES_UNAME_S=Linux \
    RAY_DOTFILES_OS_ID=ubuntu \
    bash -i -c "
      printf 'PATH=%s\n' \"\$PATH\"
      printf 'ENV=%s\n' \"\$ENV\"
    " 2>/dev/null
  )
}

# Note: This probe tests the WSL wrong-HOME recovery logic.
# It manually sources the deployed stub rather than using a genuine `bash --login`
# because a genuine login shell unconditionally resolves $HOME against the host OS
# physical filesystem (e.g., C:\Users\ray). When simulating a WSL-mounted Windows path
# (like /mnt/c/Users/ray) within a Windows Git Bash test runner, the path does not
# physically exist, causing native login resolution to bypass our mocks.
run_ubuntu_windows_home_stub_probe() {
  local linux_home=$1
  local windows_home=$2
  local windows_home_value=$3

  mkdir -p "$windows_home/some_project"
  cp "$repo_root/real/.bash_profile" "$windows_home/.bash_profile"
  cp "$repo_root/real/.profile" "$windows_home/.profile"
  cp "$repo_root/real/.bashrc" "$windows_home/.bashrc"

  (
    cd "$windows_home/some_project"
    HOME="$windows_home_value" \
    USER=ray \
    PATH="/usr/bin:/bin" \
    JAVA_HOME= \
    GRADLE_HOME= \
    myroot= \
    WT_SESSION= \
    RAY_DOTFILES_LINUX_HOME="$linux_home" \
    RAY_DOTFILES_UNAME_S=Linux \
    RAY_DOTFILES_OS_ID=ubuntu \
    bash --noprofile --norc -i -c "
      . '$windows_home/.bash_profile' >/dev/null
      printf 'HOME=%s\n' \"\$HOME\"
      printf 'PWD=%s\n' \"\$PWD\"
      printf 'HISTFILE=%s\n' \"\$HISTFILE\"
      printf 'ENV=%s\n' \"\$ENV\"
      printf 'PATH=%s\n' \"\$PATH\"
    " 2>/dev/null
  )
}

run_ubuntu_windows_home_deploy_probe() {
  local linux_home=$1
  local windows_home_value=$2

  HOME="$windows_home_value" \
  USER=ray \
  PATH="/usr/bin:/bin" \
  RAY_DOTFILES_LINUX_HOME="$linux_home" \
  RAY_DOTFILES_UNAME_S=Linux \
  sh "$repo_root/deploy.sh" >/dev/null

  [ -f "$linux_home/.bashrc" ] || fail "deploy did not copy .bashrc to Linux home"
  [ -f "$linux_home/.bash_profile" ] || fail "deploy did not copy .bash_profile to Linux home"
  cmp -s "$repo_root/real/.bashrc" "$linux_home/.bashrc" || fail "deployed .bashrc differs from real/.bashrc"
  cmp -s "$repo_root/real/.bash_profile" "$linux_home/.bash_profile" || fail "deployed .bash_profile differs from real/.bash_profile"
}

run_project_history_unset_probe() {
  local home_dir=$1

  HOME="$home_dir" \
  PATH="/usr/bin:/bin" \
  JAVA_HOME= \
  GRADLE_HOME= \
  myroot= \
  WT_SESSION= \
  RAY_DOTFILES_UNAME_S=Linux \
  RAY_DOTFILES_OS_ID=ubuntu \
  bash --noprofile --norc -i -c "
    set -u
    unset RAY_PROJECT_HISTORY
    . '$repo_root/bash/bashrc' >/dev/null
    __ray_prompt_command
    printf 'project_history_unset=ok\n'
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
  "$repo_root/direnv/envrc"
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
grep -Fq 'FontSize=20' "$repo_root/real/.minttyrc" || fail "real/.minttyrc target changed"
pass "bootstrap files still point to intended tracked files"

grep -Fq 'conda.sh' "$repo_root/bash/bashrc-windows" || fail "Windows Conda loading missing"
pass "Windows login-profile Conda path is preserved"

direnv_helper_path="direnv/envrc"
stale_direnv_helper_path="${direnv_helper_path}.txt"

[ -f "$repo_root/$direnv_helper_path" ] || fail "$direnv_helper_path is missing"
[ ! -e "$repo_root/$stale_direnv_helper_path" ] || fail "$stale_direnv_helper_path should not exist"
pass "direnv helper library uses direnv/envrc"

if grep -RIn "${stale_direnv_helper_path}" "$repo_root" \
  --exclude-dir=.git \
  --exclude-dir=.tmp.driveupload >/dev/null; then
  fail "stale ${stale_direnv_helper_path} reference found"
fi

grep -RIn 'direnv/envrc' "$repo_root/README.md" "$repo_root/direnv/readme.txt" "$repo_root/direnv/envrc" >/dev/null || fail "direnv/envrc is not documented or referenced"
pass "documentation and source references use direnv/envrc"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

linux_home="$tmp_root/linux-home"
windows_home="$tmp_root/windows-home"
make_test_home "$linux_home"
make_test_home "$windows_home"
mkdir -p "$linux_home/bin" "$linux_home/dev" "$linux_home/anaconda3/etc/profile.d"
printf 'export RAY_TEST_UBUNTU_CONDA=loaded\n' >"$linux_home/anaconda3/etc/profile.d/conda.sh"

linux_output="$(run_login_probe "$linux_home" Linux ubuntu | tr -d '\r')"
windows_output="$(run_login_probe "$windows_home" MINGW64_NT-10.0 '' | tr -d '\r')"
project_history_unset_output="$(run_project_history_unset_probe "$linux_home")"

assert_line_equals "$linux_output" "HOME=$linux_home" "Ubuntu HOME changed when already Linux-local"
for windows_home_value in /c/Users/ray /mnt/c/Users/ray /mnt/c/users/ray 'C:\Users\ray'; do
  ubuntu_windows_home_output="$(run_ubuntu_windows_home_stub_probe "$linux_home" "$windows_home" "$windows_home_value" | tr -d '\r')"
  assert_line_equals "$ubuntu_windows_home_output" "HOME=$linux_home" "Ubuntu HOME was not reset from Windows home: $windows_home_value"
  assert_line_equals "$ubuntu_windows_home_output" "HISTFILE=$linux_home/.bash_history" "Ubuntu HISTFILE used Windows home: $windows_home_value"
  assert_line_equals "$ubuntu_windows_home_output" "ENV=$linux_home/dotfiles/sh/shrc" "Ubuntu ENV used Windows home: $windows_home_value"
  assert_line_equals "$ubuntu_windows_home_output" "PWD=$windows_home/some_project" "Ubuntu PWD changed"
  if ! printf '%s\n' "$ubuntu_windows_home_output" | grep -q "^PATH=$linux_home/dotfiles/bin:$linux_home/bin:"; then
    fail "Ubuntu PATH did not have Linux home paths at the front: $ubuntu_windows_home_output"
  fi
done
pass "Ubuntu startup resets imported Windows HOME before deriving paths"

run_ubuntu_windows_home_deploy_probe "$linux_home" /mnt/c/users/ray
pass "deploy targets Linux home when Ubuntu HOME starts as Windows home"

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

assert_line_equals "$linux_output" "JAVA_HOME=" "Linux JAVA_HOME unexpectedly has a value"
assert_line_equals "$linux_output" "GRADLE_HOME=" "Linux GRADLE_HOME unexpectedly has a value"
assert_contains "$linux_output" "RAY_TEST_UBUNTU_CONDA=loaded" "Ubuntu Conda guard did not load existing conda.sh"
pass "Ubuntu startup does not require JAVA_HOME or GRADLE_HOME"

assert_line_equals "$project_history_unset_output" "project_history_unset=ok" "project history failed when RAY_PROJECT_HISTORY was unset"
pass "project history hook tolerates unset RAY_PROJECT_HISTORY"

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
pass "history settings are preserved"

windows_login_output="$(run_login_probe "$windows_home" MINGW64_NT-10.0 '')"
assert_line_equals "$windows_login_output" "PWD=$windows_home/some_project" "Windows login shell changed directories from some_project"
if ! printf '%s\n' "$windows_login_output" | grep -q "PATH=\(.*:\)\?$windows_home/dotfiles/bin:$windows_home/bin:"; then
  fail "Windows login shell did not put Windows home paths at the front (after system paths): $windows_login_output"
fi
assert_contains "$windows_login_output" 'ENV='"$windows_home"'/dotfiles/sh/shrc' "Windows login shell missing ENV"

linux_login_output="$(run_login_probe "$linux_home" Linux ubuntu)"
assert_line_equals "$linux_login_output" "PWD=$linux_home/some_project" "Linux login shell changed directories from some_project"
if ! printf '%s\n' "$linux_login_output" | grep -q "^PATH=$linux_home/dotfiles/bin:$linux_home/bin:"; then
  fail "Linux login shell did not put Linux home paths at the front of PATH: $linux_login_output"
fi
assert_contains "$linux_login_output" 'ENV='"$linux_home"'/dotfiles/sh/shrc' "Linux login shell missing ENV"
pass "Login shells correctly initialize environments and preserve PWD"

linux_silence_output="$(run_silence_probe "$linux_home" Linux ubuntu | grep -v 'cannot set terminal process group' | grep -v 'no job control in this shell' | tr -d '\r')"
if [ "$linux_silence_output" != "PROBE_START" ]; then
  fail "Startup is not silent! Unsolicited output detected: $linux_silence_output"
fi
pass "Login shell startup is completely silent"


idempotency_output="$(run_idempotency_probe "$windows_home" MINGW64_NT-10.0 '')"
if [ "$(printf '%s' "$idempotency_output" | grep -o "$windows_home/bin:" | wc -l)" -ne 1 ]; then
  fail "Idempotency test failed: PATH has duplicate or missing entries. PATH=$idempotency_output"
fi
pass "Environment layer is idempotent"

nonlogin_inheritance_output="$(run_nonlogin_inheritance_probe "$linux_home")"
assert_line_equals "$nonlogin_inheritance_output" "ENV=/inherited/env" "Non-login shell failed to inherit ENV"
assert_line_equals "$nonlogin_inheritance_output" "PATH=/inherited/path:/usr/bin:/bin" "Non-login shell reconstructed PATH instead of inheriting"
pass "Non-login shells inherit parent environment without rebuilding"


if grep -U $'\r' "$repo_root/profile" "$repo_root"/bash/* "$repo_root"/sh/* "$repo_root"/real/.* 2>/dev/null; then
  fail "CR bytes found in repository-controlled startup files! Files must be LF only."
fi
pass "All repository-controlled startup files are LF only"
