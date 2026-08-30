#!/bin/sh
# Compatibility entry point for installing the tracked Windows Terminal settings.
# settings.json is the canonical profile/color configuration.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dotfiles_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

exec "$dotfiles_dir/put-windows-settings.sh"
