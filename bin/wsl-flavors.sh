#!/bin/sh
set -eu

# Pipe the same shell code into one or more WSL distros.
# Defaults to the user-facing Ubuntu distros detected on this machine.

usage() {
  cat <<'EOF'
Usage:
  wsl-flavors.sh [options] [-- command...]

Options:
  -d, --distro NAME     Run only this distro; may be repeated.
  --all                Include Docker's WSL distros too.
  --shell PATH         Shell to run inside WSL. Default: /bin/sh
  --list               Show registered WSL distros.
  -h, --help           Show this help.

Examples:
  printf 'uname -a\ncat /etc/os-release | head\n' | ./wsl-flavors.sh
  ./wsl-flavors.sh -d Ubuntu-24.04 -- printf '%s\n' hello-from-wsl
  ./wsl-flavors.sh --shell /bin/bash -- 'echo "$WSL_DISTRO_NAME"; pwd'
EOF
}

shell_path=/bin/sh
include_docker=0
explicit_distros=

wsl_run() {
  MSYS2_ARG_CONV_EXCL='*' wsl.exe "$@"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--distro)
      [ "$#" -ge 2 ] || { echo "missing distro name after $1" >&2; exit 2; }
      explicit_distros="${explicit_distros}${explicit_distros:+
}$2"
      shift 2
      ;;
    --all)
      include_docker=1
      shift
      ;;
    --shell)
      [ "$#" -ge 2 ] || { echo "missing shell path after --shell" >&2; exit 2; }
      shell_path=$2
      shift 2
      ;;
    --list)
      wsl_run -l -v
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [ -n "$explicit_distros" ]; then
  distros=$explicit_distros
elif [ "$include_docker" -eq 1 ]; then
  distros='Ubuntu-24.04
Ubuntu
docker-desktop
docker-desktop-data'
else
  distros='Ubuntu-24.04
Ubuntu'
fi

tmp=${TMPDIR:-/tmp}/wsl-flavors.$$.sh
trap 'rm -f "$tmp"' EXIT HUP INT TERM

if [ "$#" -gt 0 ]; then
  printf '%s\n' "$*" > "$tmp"
elif [ -t 0 ]; then
  if [ "$(printf '%s\n' "$distros" | sed '/^$/d' | wc -l | tr -d ' ')" = "1" ]; then
    MSYS2_ARG_CONV_EXCL='*' exec wsl.exe -d "$distros" -- "$shell_path"
  fi
  usage >&2
  echo >&2
  echo "No stdin or command was provided. Pipe code in, or pass a command after --." >&2
  exit 2
else
  tr -d '\r' > "$tmp"
fi

status=0
for distro in $distros; do
  [ -n "$distro" ] || continue
  printf '\n== %s ==\n' "$distro"
  if ! wsl_run -d "$distro" -- "$shell_path" -s < "$tmp"; then
    status=1
  fi
done

exit "$status"
