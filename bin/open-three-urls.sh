#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  open-three-urls.sh [browser] URL1 URL2 URL3

Browsers:
  chrome, edge, brave, firefox

If browser is omitted, chrome is used.

Examples:
  open-three-urls.sh https://chatgpt.com https://github.com https://news.ycombinator.com
  open-three-urls.sh edge https://example.com https://openai.com https://github.com
EOF
}

browser=chrome

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  chrome|edge|brave|firefox)
    browser=$1
    shift
    ;;
esac

if [ "$#" -ne 3 ]; then
  usage >&2
  exit 2
fi

path_prefix=/c
if [ -d /mnt/c/Windows ]; then
  path_prefix=/mnt/c
fi

find_browser() {
  case "$1" in
    chrome)
      set -- \
        "$path_prefix/Program Files/Google/Chrome/Application/chrome.exe" \
        "$path_prefix/Program Files (x86)/Google/Chrome/Application/chrome.exe"
      ;;
    edge)
      set -- \
        "$path_prefix/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
        "$path_prefix/Program Files/Microsoft/Edge/Application/msedge.exe"
      ;;
    brave)
      set -- \
        "$path_prefix/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe" \
        "$path_prefix/Program Files (x86)/BraveSoftware/Brave-Browser/Application/brave.exe"
      ;;
    firefox)
      set -- \
        "$path_prefix/Program Files/Mozilla Firefox/firefox.exe" \
        "$path_prefix/Program Files (x86)/Mozilla Firefox/firefox.exe"
      ;;
    *)
      return 1
      ;;
  esac

  for candidate do
    if [ -x "$candidate" ] || [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

browser_exe=$(find_browser "$browser") || {
  echo "could not find browser executable for: $browser" >&2
  exit 1
}

MSYS2_ARG_CONV_EXCL='*' "$browser_exe" --new-window "$1" "$2" "$3" >/dev/null 2>&1 &
