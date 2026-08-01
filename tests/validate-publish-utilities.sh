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

publish_dir="$repo_root/publish-utilities"
default_jar="$HOME/eclipse-workspace/util/build/libs/utilities-0.0.jar"

[ -f "$default_jar" ] || fail "default utilities jar is missing: $default_jar"
gradle -p "$publish_dir" verifyUtilitiesJar --no-daemon >/dev/null
pass "publish-utilities resolves the default utilities jar"

git -C "$repo_root" check-ignore -q "$publish_dir/.gradle/validation-probe" ||
  fail "publish-utilities Gradle cache is not ignored"
pass "publish-utilities Gradle cache is ignored"

git -C "$repo_root" check-ignore -q "$publish_dir/build/validation-probe" ||
  fail "publish-utilities build output is not ignored"
pass "publish-utilities build output is ignored"
