#!/bin/sh
# Windows 11 Workbench - Case-Insensitive Gitignore File Locator

# Use the current directory as the default starting point if no path is passed
START_DIR="${1:-.}"

echo "=== Searching for gitignore files in: $(cd "$START_DIR" && pwd) ==="
echo "------------------------------------------------------------------------"

# 1. Finds official .gitignore files case-insensitively
# 2. Finds filenames containing "gitignore", "git-ignore", "git ignore", or "getignore"
find "$START_DIR" -type f \( \
    -iname ".gitignore" -o \
    -iname "*gitignore*" -o \
    -iname "*git-ignore*" -o \
    -iname "*git ignore*" -o \
    -iname "*getignore*" -o \
    -iname "*get ignore*" \
\) 2>/dev/null

echo "------------------------------------------------------------------------"
echo "Search complete."
