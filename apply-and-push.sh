#!/usr/bin/env bash
# Apply the dotfiles patch and push it to origin.
#
# Usage:
#   1. Put this script AND 0001-clear-stale-bug-resolve-open-questions.patch
#      in the same folder.
#   2. cd into your local dotfiles repo (e.g. the folder containing AGENTS.md)
#   3. Run this script, pointing it at the patch file, e.g.:
#        bash /path/to/apply-and-push.sh /path/to/0001-clear-stale-bug-resolve-open-questions.patch
#
# What it does:
#   - Verifies you're inside a git repo with a clean working tree
#   - Applies the patch as a real commit (git am), preserving the
#     original commit message and author
#   - Pushes to origin/<current branch>

set -euo pipefail

PATCH_FILE="${1:?Usage: $0 /path/to/0001-clear-stale-bug-resolve-open-questions.patch}"

if [ ! -f "$PATCH_FILE" ]; then
  echo "Error: patch file not found: $PATCH_FILE" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this from inside your local dotfiles git repo." >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is not clean. Commit or stash your changes first." >&2
  git status --short
  exit 1
fi

echo "Applying patch..."
git am "$PATCH_FILE"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "Pushing to origin/$BRANCH..."
git push origin "$BRANCH"

echo "Done. Latest commit:"
git log -1 --oneline
