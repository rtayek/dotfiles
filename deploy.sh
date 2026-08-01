#!/bin/sh
# Copy the real dot files from this repository into the home directory.

set -eu

ray_deploy_uname="${RAY_DOTFILES_UNAME_S:-$(uname -s 2>/dev/null || printf unknown)}"
ray_deploy_target_home="$HOME"

case "$ray_deploy_uname:$HOME" in
    Linux*:/mnt/[A-Za-z]/[Uu]sers/*|Linux*:/[A-Za-z]/[Uu]sers/*|Linux*:[A-Za-z]:/[Uu]sers/*|Linux*:[A-Za-z]:\\[Uu]sers\\*)
        ray_deploy_target_home="${RAY_DOTFILES_LINUX_HOME:-/home/${USER:-ray}}"
        ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REAL_DIR="$SCRIPT_DIR/real"

if [ ! -d "$REAL_DIR" ]; then
    printf 'error: real directory not found: %s\n' "$REAL_DIR" >&2
    exit 1
fi

for f in "$REAL_DIR"/.[!.]* "$REAL_DIR"/..?*; do
    [ -f "$f" ] || continue

    name=$(basename -- "$f")

    # .gitignore is a template only; do not deploy it.
    [ "$name" = ".gitignore" ] && continue

    cp -p -- "$f" "$ray_deploy_target_home/$name"
    printf 'copied %s -> %s\n' "$name" "$ray_deploy_target_home/$name"
done

printf '%s\n' "done."
