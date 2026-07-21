#!/bin/sh

# find-git-repos.sh
# Recursively find Git repositories that need attention.
#
# Usage:
#   ./find-git-repos.sh [root-folder]
#
# If no root folder is given, current directory is used.

root="${1:-.}"

[ -d "$root" ] || {
    echo "error: not a directory: $root" >&2
    exit 1
}

find "$root" -type d -name .git -prune -print | while IFS= read -r gitdir
do
    repo_dir=$(dirname "$gitdir")
    upstream=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    dirty=$(git -C "$repo_dir" status --porcelain)
    ahead_behind=$(git -C "$repo_dir" rev-list --left-right --count HEAD...@{u} 2>/dev/null)

    reasons=

    [ -n "$upstream" ] || reasons="${reasons} no-upstream"

    if [ -n "$ahead_behind" ]; then
        set -- $ahead_behind
        [ "$1" = 0 ] || reasons="${reasons} ahead=$1"
        [ "$2" = 0 ] || reasons="${reasons} behind=$2"
    else
        reasons="${reasons} no-ahead-behind"
    fi

    [ -z "$dirty" ] || reasons="${reasons} dirty"
    git -C "$repo_dir" ls-files '.settings/*' | grep -q . &&
        reasons="${reasons} tracked-settings"

    if [ -n "$reasons" ]; then
        printf '%s:%s\n' "$repo_dir" "$reasons"
    fi
done
