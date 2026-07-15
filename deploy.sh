#!/bin/sh
# Copy the real dot files from the repo into the home directory.

REAL_DIR="$HOME/dotfiles/real"

for f in "$REAL_DIR"/.*; do
  name=$(basename "$f")
  # skip . and ..
  [ "$name" = "." ] && continue
  [ "$name" = ".." ] && continue
  # .gitignore is a template only; do not deploy it
  [ "$name" = ".gitignore" ] && continue
  [ -f "$f" ] || continue
  cp "$f" "$HOME/$name"
  echo "copied $name -> $HOME/$name"
done

echo "done."
