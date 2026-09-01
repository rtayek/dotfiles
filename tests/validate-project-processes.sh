#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
helper="$repo_root/bin/project-processes.sh"
tmp_root="$(mktemp -d)"
mock_bin="$tmp_root/bin"
target_pid=
control_pid=

cleanup() {
  [ -z "$target_pid" ] || kill -KILL "$target_pid" 2>/dev/null || true
  [ -z "$control_pid" ] || kill -KILL "$control_pid" 2>/dev/null || true
  rm -rf "$tmp_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

mkdir -p "$mock_bin"

cat >"$mock_bin/ps" <<'EOF'
#!/bin/sh

print_row() {
  printf '%9s %7s %7s %10s %5s %11s %8s %s\n' "$@"
}

pid=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p)
      pid=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

print_row PID PPID PGID WINPID TTY UID STIME COMMAND

if [ -n "$pid" ]; then
  if [ "$pid" = 4242 ]; then
    print_row 4242 0 0 4242 '?' 197609 12:10 'C:\Program Files\WindowsApps\WindowsTerminal.exe'
  elif [ -n "${RAY_TEST_PID-}" ] && [ "$pid" = "$RAY_TEST_PID" ]; then
    print_row "$pid" 1 "$pid" "$pid" '?' 197609 12:11 /usr/bin/sleep
  fi
  exit 0
fi

print_row 70001 0 0 1001 '?' 197609 'Aug 30' 'C:\Program Files\WindowsApps\WindowsTerminal.exe'
print_row 70002 0 0 1002 '?' 197609 12:02 'C:\Program Files\WindowsApps\OpenConsole.exe'
print_row 70003 70002 70003 1003 pty0 197609 12:03 'C:\Program Files\Git\bin\bash.exe'
print_row 70004 70003 70003 1004 pty0 197609 12:04 'C:\Program Files\Git\mingw64\bin\git-remote-https.exe'
print_row 70005 70003 70003 1005 pty0 197609 12:05 'C:\Program Files\Java\jdk-25\bin\java.exe'
print_row 70006 0 0 1006 '?' 197609 12:06 'C:\Windows\System32\notepad.exe'
EOF

cat >"$mock_bin/jps" <<'EOF'
#!/bin/sh
printf '%s\n' '1005 com.example.Main -Dsample.process.label=Sample:UI'
EOF

chmod 755 "$mock_bin/ps" "$mock_bin/jps"

bash -n "$helper"

output="$(PATH="$mock_bin:/usr/bin:/bin" "$helper")"
for type in WindowsTerminal OpenConsole Bash Git Java; do
  printf '%s\n' "$output" | grep -Eq "^${type}[[:space:]]" ||
    fail "inventory did not label $type"
done

printf '%s\n' "$output" | grep -Eq '^Git[[:space:]]+70004[[:space:]]+1004[[:space:]]+70003[[:space:]]+12:04' ||
  fail "inventory did not preserve Git PID, WINPID, PPID, and start time"
printf '%s\n' "$output" | grep -Fq 'Aug 30' ||
  fail "inventory did not preserve a multiword start time"
printf '%s\n' "$output" | grep -Fq '1005 com.example.Main -Dsample.process.label=Sample:UI' ||
  fail "inventory did not include jps -lv output"
if printf '%s\n' "$output" | grep -Fq 'notepad.exe'; then
  fail "inventory included an unrelated process"
fi
pass "inventory labels relevant processes and includes Task Manager PID mapping"

cat >"$mock_bin/jps" <<'EOF'
#!/bin/sh
printf 'unavailable\n' >&2
exit 1
EOF
silent_output="$(PATH="$mock_bin:/usr/bin:/bin" "$helper")"
if printf '%s\n' "$silent_output" | grep -Fq 'JVM processes'; then
  fail "failed jps invocation produced a JVM section"
fi
pass "unavailable JVM details are skipped silently"

if PATH="$mock_bin:/usr/bin:/bin" "$helper" --term 4242 >"$tmp_root/refusal" 2>&1; then
  fail "helper allowed WindowsTerminal termination"
fi
grep -Fq 'refusing to terminate shared WindowsTerminal.exe' "$tmp_root/refusal" ||
  fail "WindowsTerminal refusal was not explicit"
pass "shared WindowsTerminal termination is refused"

sleep 30 &
target_pid=$!
sleep 30 &
control_pid=$!

term_output="$(RAY_TEST_PID="$target_pid" PATH="$mock_bin:/usr/bin:/bin" \
  "$helper" --term "$target_pid")"

set +e
wait "$target_pid" 2>/dev/null
target_status=$?
set -e
target_pid=

[ "$target_status" -ne 0 ] || fail "TERM target exited without a signal status"
kill -0 "$control_pid" 2>/dev/null || fail "exact-PID termination affected another process"
printf '%s\n' "$term_output" | grep -Fq "Sending TERM to exact MSYS PID" ||
  fail "TERM action did not identify its exact target"

kill -TERM "$control_pid"
wait "$control_pid" 2>/dev/null || true
control_pid=
pass "TERM is sent only to the explicitly selected PID"

if grep -Eq '(^|[[:space:]])(pkill|killall)([[:space:]]|$)|taskkill[^\n]*/IM' "$helper"; then
  fail "helper contains broad process-name termination"
fi
pass "helper contains no broad process-name termination"
