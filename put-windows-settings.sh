#!/bin/sh
# Windows 11 Workbench - Push your real repo settings to the Windows system

DOTFILES_DIR="$HOME/dotfiles"
SYSTEM_JSON="$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"

echo "Pushing: Copying real settings from repo into obscure Windows directory..."
cp "$DOTFILES_DIR/settings.json" "$SYSTEM_JSON"
echo "Done! Windows Terminal is now using your real repository file."