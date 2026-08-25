#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
wsl_flavors=$script_dir/wsl-flavors.sh

if [ ! -x "$wsl_flavors" ] && [ ! -f "$wsl_flavors" ]; then
  echo "missing helper: $wsl_flavors" >&2
  exit 1
fi

run_example() {
  printf '\n### %s\n' "$1"
}

run_example "Example 1: pipe code into the default Ubuntu distros"
printf 'uname -a\ncat /etc/os-release | head\n' | "$wsl_flavors"

run_example "Example 2: run one command in Ubuntu-24.04"
"$wsl_flavors" -d Ubuntu-24.04 -- 'printf "%s\n" hello-from-wsl'

run_example "Example 3: run code through /bin/bash"
"$wsl_flavors" --shell /bin/bash -- 'echo "$WSL_DISTRO_NAME"; pwd'
