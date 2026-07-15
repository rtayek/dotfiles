#!/bin/sh
# Windows 11 Workbench - Copy configurations to your local repository

DOTFILES_DIR="$HOME/dotfiles"
SYSTEM_JSON="$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"

echo "Copying your master terminal settings into your repository..."

# Copy the file directly into your dotfiles directory
cp "$SYSTEM_JSON" "$DOTFILES_DIR/settings.json"

echo "Success! File copied cleanly into your dotfiles directory."
