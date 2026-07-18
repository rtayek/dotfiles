#!/bin/sh

find . -type d -name .git -print |
while IFS= read -r g; do
  repo=$(dirname "$g")
  if git -C "$repo" ls-files | grep -qF '.bash_history'; then
    echo "FOUND in $repo"
  fi
done
