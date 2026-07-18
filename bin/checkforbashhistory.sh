#!/bin/sh

find . -type d -name .git -print |
while IFS= read -r g; do
  repo=$(dirname "$g")
  git -C "$repo" ls-files | grep -qF '.bash_history' &&
    echo "FOUND in $repo"
done
