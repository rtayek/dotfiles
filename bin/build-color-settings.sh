#!/bin/sh
# Windows 11 Workbench - Complete High-Visibility Profile Builder

SYSTEM_JSON="$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
REPO_JSON="$HOME/dotfiles/settings.json"

echo "Building a fresh, high-visibility settings template..."

# Writes a perfectly structured, complete configuration file straight to dotfiles
cat << 'JSON' > "$REPO_JSON"
{
    "$schema": "https://aka.ms",
    "confirmCloseAllTabs": false,
    "profiles":
    {
        "defaults":
        {
            "fontSize": 18,
            "fontFace": "Lucida Console",
            "useAcrylic": false
        },
        "list":
        [
            { "name": "Red", "commandline": "bash.exe", "background": "#3a0000" },
            { "name": "Green", "commandline": "bash.exe", "background": "#003a00" },
            { "name": "Blue", "commandline": "bash.exe", "background": "#00003a" },
            { "name": "Cyan", "commandline": "bash.exe", "background": "#003a3a" },
            { "name": "Magenta", "commandline": "bash.exe", "background": "#3a003a" },
            { "name": "Yellow", "commandline": "bash.exe", "background": "#3a3a00" }
        ]
    }
}
JSON

echo "Copying fresh color profiles straight to the active Windows directory..."
cp "$REPO_JSON" "$SYSTEM_JSON"

echo "Success! Your 6 color-coded profiles are live with a massive 18pt font."
