#!/bin/sh
# Inspect project-related Windows processes and terminate only an explicit PID.

set -eu

usage() {
  cat <<'EOF'
Usage:
  project-processes.sh
  project-processes.sh --term PID
  project-processes.sh --kill PID

Without arguments, list Windows Terminal, OpenConsole, Bash, Git, and Java
processes. PID is the MSYS PID accepted by the Git Bash kill builtin; WINPID is
the process ID shown by Windows Task Manager.

Options:
  --term PID   Send TERM to one exact MSYS PID.
  --kill PID   Send KILL to one exact MSYS PID.
  -h, --help   Show this help.
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

format_processes() {
  include_all=$1

  awk -v include_all="$include_all" '
    function process_type(executable, name) {
      name = tolower(executable)
      gsub(/\\/, "/", name)
      sub(/^.*\//, "", name)

      if (name == "windowsterminal.exe") return "WindowsTerminal"
      if (name == "openconsole.exe") return "OpenConsole"
      if (name == "bash" || name == "bash.exe" || name == "git-bash.exe") return "Bash"
      if (name == "git" || name == "git.exe" || name ~ /^git[-.]/) return "Git"
      if (name == "java" || name == "java.exe" || name == "javaw" || name == "javaw.exe") return "Java"
      return ""
    }

    NR == 1 {
      if ($1 != "PID" || $2 != "PPID" || $4 != "WINPID" ||
          $7 != "STIME" || $8 != "COMMAND") exit 2
      next
    }

    {
      pid = $1
      ppid = $2
      winpid = $4
      started = $7
      command_field = 8

      if ($7 ~ /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$/ &&
          $8 ~ /^[0-9][0-9]?$/) {
        started = $7 " " $8
        command_field = 9
      }

      executable = $command_field
      for (field = command_field + 1; field <= NF; field++)
        executable = executable " " $field
      type = process_type(executable)

      if (pid == "" || (type == "" && include_all != 1)) next
      if (type == "") type = "Other"

      printf "%-15s %7s %7s %7s %-12s %s\n", \
        type, pid, winpid, ppid, started, executable
    }
  '
}

print_header() {
  printf '%-15s %7s %7s %7s %-12s %s\n' \
    TYPE PID WINPID PPID START EXECUTABLE
}

read_processes() {
  if ! process_list=$(ps -W -l "$@" 2>/dev/null); then
    fail "Git Bash ps -W is unavailable"
  fi
}

show_inventory() {
  read_processes
  if ! formatted=$(printf '%s\n' "$process_list" | format_processes 0); then
    fail "unexpected output from ps -W -l"
  fi

  print_header
  [ -z "$formatted" ] || printf '%s\n' "$formatted"

  if command -v jps >/dev/null 2>&1; then
    jvm_processes=$(jps -lv 2>/dev/null) || jvm_processes=
    if [ -n "$jvm_processes" ]; then
      printf '\nJVM processes (jps -lv):\n%s\n' "$jvm_processes"
    fi
  fi
}

terminate_pid() {
  signal=$1
  pid=$2

  case "$pid" in
    ''|*[!0-9]*) fail "PID must contain digits only" ;;
    0|1) fail "refusing reserved PID $pid" ;;
  esac

  read_processes -p "$pid"
  if ! target=$(printf '%s\n' "$process_list" | format_processes 1); then
    fail "unexpected output from ps -W -l"
  fi
  [ -n "$target" ] || fail "MSYS PID not found: $pid"

  case "$target" in
    WindowsTerminal*) fail "refusing to terminate shared WindowsTerminal.exe (PID $pid)" ;;
  esac

  print_header
  printf '%s\n\n' "$target"
  printf 'Sending %s to exact MSYS PID %s.\n' "$signal" "$pid"

  if ! kill "-$signal" "$pid"; then
    fail "could not send $signal to MSYS PID $pid"
  fi
}

case "$#" in
  0)
    show_inventory
    ;;
  1)
    case "$1" in
      -h|--help) usage ;;
      *) usage >&2; fail "an action and an explicit PID are required" ;;
    esac
    ;;
  2)
    case "$1" in
      --term) terminate_pid TERM "$2" ;;
      --kill) terminate_pid KILL "$2" ;;
      *) usage >&2; fail "unknown action: $1" ;;
    esac
    ;;
  *)
    usage >&2
    fail "too many arguments"
    ;;
esac
