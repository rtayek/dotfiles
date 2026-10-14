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

projectsFile=${projectsFile:-${PROJECTS_FILE:-"$HOME/.config/ray/projects.tsv"}}
projectsRoot=${projectsRoot:-${PROJECTS_ROOT:-"$HOME/eclipse-workspace"}}
publish_dir="$repo_root/publish-utilities"

registry_path=$(
  awk -F '\t' '$1 == "util" { print $2; exit }' "$projectsFile"
)
[ -n "$registry_path" ] || fail "util is not registered in $projectsFile"

case "$registry_path" in
  "~") util_dir=$HOME ;;
  "~/"*) util_dir="$HOME/${registry_path#??}" ;;
  /*|[A-Za-z]:/*) util_dir=$registry_path ;;
  *) util_dir="$projectsRoot/$registry_path" ;;
esac

default_jar="$util_dir/build/libs/util-0.0.jar"

[ -f "$default_jar" ] || fail "default utilities jar is missing: $default_jar"
gradle -p "$publish_dir" verifyUtilitiesJar --no-daemon >/dev/null
pass "publish-utilities resolves the registered utilities jar"

git -C "$repo_root" check-ignore -q "$publish_dir/.gradle/validation-probe" ||
  fail "publish-utilities Gradle cache is not ignored"
pass "publish-utilities Gradle cache is ignored"

git -C "$repo_root" check-ignore -q "$publish_dir/build/validation-probe" ||
  fail "publish-utilities build output is not ignored"
pass "publish-utilities build output is ignored"
