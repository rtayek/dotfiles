#!/bin/sh

# find-git-repos.sh
# Recursively find Git repositories under a given directory.
#
# Usage:
#   ./find-git-repos.sh [root-folder]
#
# If no root folder is given, current directory is used.

root="${1:-.}"

if [ ! -d "$root" ]; then
    echo "error: not a directory: $root" >&2
    exit 1
fi

find "$root" -type d -name .git -prune -print | while IFS= read -r gitdir
do
    repo_dir=$(dirname "$gitdir")
    printf '%s\n' "$repo_dir"
done
