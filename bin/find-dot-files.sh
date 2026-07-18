#!/bin/sh
# Windows 11 Workbench - Find non-directory files starting with a dot

echo "Searching your home directory for hidden files starting with a dot..."
echo "------------------------------------------------------------------------"

# -maxdepth 1 limits the search to the top level of your home directory
# -type f ensures we only list real files, completely ignoring folders
# -name ".*" targets files that start with a period (like .bashrc or .login)
find "$HOME" -maxdepth 1 -type f -name ".*"

echo "------------------------------------------------------------------------"
echo "Search complete."
