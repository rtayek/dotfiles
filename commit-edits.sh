#!/bin/sh
# Commit the current dotfiles edits after running the local validation checks.

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$repo_dir"

message=${1:-"Fix Ubuntu HOME startup handling"}

printf '%s\n' "Running validation..."
bash tests/validate-shell-startup.sh
bash tests/validate-terminal-settings.sh

if [ -f tests/validate-publish-utilities.sh ]; then
    bash tests/validate-publish-utilities.sh
fi

printf '%s\n' "Staging edited files..."
git add -- \
    bash/bashrc \
    deploy.sh \
    real/.bash_profile \
    real/.bashrc \
    commit-edits.sh \
    tests/validate-shell-startup.sh

if [ -f tests/validate-publish-utilities.sh ]; then
    git add -- tests/validate-publish-utilities.sh
fi

if git diff --cached --quiet; then
    printf '%s\n' "No staged changes to commit."
    exit 0
fi

git status --short
git commit -m "$message"
