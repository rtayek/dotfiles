#!/bin/sh

echo "=== Git version ==="
git --version
echo

echo "=== System config ==="
git config --system --list 2>/dev/null || echo "(no system config or insufficient permissions)"
echo

echo "=== Global config ==="
git config --global --list 2>/dev/null || echo "(no global config)"
echo

echo "=== Local (repo) config ==="
git config --local --list 2>/dev/null || echo "(not in a git repo)"
echo

echo "=== All configs with origin (authoritative) ==="
git config --list --show-origin
echo

echo "=== CRLF-relevant settings (with origin) ==="
for key in core.autocrlf core.safecrlf core.eol core.whitespace; do
    git config --show-origin --get "$key" 2>/dev/null && :
done

