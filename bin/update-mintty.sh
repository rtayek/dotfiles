#!/bin/sh
# Windows 11 Workbench - High-Visibility Mintty Configuration

CONFIG_FILE="$HOME/.minttyrc"

echo "Injecting massive, high-contrast text configurations into your .minttyrc file..."

# Overwrite or create a clean, oversized text configuration
cat << 'MINTTY' > "$CONFIG_FILE"
# High-Visibility Terminal Settings
Font=Lucida Console
FontSize=20
FontWeight=700
BoldAsFont=yes
CursorType=block
CursorBlinking=yes
Rows=24
Columns=80
MINTTY

echo "Success! Your standalone Git Bash configuration is updated."
