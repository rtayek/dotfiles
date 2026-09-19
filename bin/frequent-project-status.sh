#!/bin/sh
# Show Git status for every project registered with launch-webterms.sh.

registry=$(CDPATH= cd "$(dirname "$0")" && pwd)/launch-webterms.sh

if [ ! -r "$registry" ]; then
  printf 'error: cannot read project registry: %s\n' "$registry" >&2
  exit 1
fi

awk '$1 == "restart_webterm" && NF >= 3 { print $3 }' "$registry" | (
  status=0
  while IFS= read -r project
  do
    printf '=== %s ===\n' "$(basename "$project")"

    if [ ! -d "$project" ]; then
      printf 'missing: %s\n\n' "$project" >&2
      status=1
      continue
    fi

    if ! git -C "$project" status --short --branch; then
      status=1
    fi
    printf '\n'
  done
  exit "$status"
)
