#!/usr/bin/env bash
# new-project.sh — wire a new project up to the standard set of tools.
#
# Runs, in order:
#   1. dotmdfiles/bin/setup-project.sh   (CLAUDE.md, AGENTS.md, persona.md, human.md)
#   2. next free webterm port + launch-webterms.sh entry
#   3. project-home.html generated from the dotfiles template
#   4. .envrc with PROJECT_TERMINAL_NAME (and useProjectHistory if new)
#
# Usage:
#   new-project.sh <name> [target-dir] [port]
#
#   name         Project name, used for the title/links (e.g. five-rules)
#   target-dir   Defaults to ~/eclipse-workspace/<name>
#   port         Defaults to the next unused port after the highest one
#                already in launch-webterms.sh
#
# Example:
#   new-project.sh five-rules
#   new-project.sh five-rules ~/eclipse-workspace/five-rules 1034

set -euo pipefail

DOTFILES="$HOME/dotfiles"
DOTMDFILES="$HOME/eclipse-workspace/dotmdfiles"
WEBTERMS="$DOTFILES/bin/launch-webterms.sh"
MACRO="$DOTFILES/templates/project-home.html.macro"

NAME="${1:?usage: new-project.sh <name> [target-dir] [port]}"
DIR="${2:-$HOME/eclipse-workspace/$NAME}"
PORT="${3:-}"

[ -f "$WEBTERMS" ] || { echo "missing $WEBTERMS" >&2; exit 1; }
[ -f "$MACRO" ] || { echo "missing $MACRO" >&2; exit 1; }
[ -x "$DOTMDFILES/bin/setup-project.sh" ] ||
  { echo "missing $DOTMDFILES/bin/setup-project.sh" >&2; exit 1; }

if [ -z "$PORT" ]; then
  PORT=$(grep -oE 'restart_webterm [0-9]+' "$WEBTERMS" |
    awk '{print $2}' | sort -n | tail -1)
  PORT=$((PORT + 1))
fi

echo "Project:    $NAME"
echo "Directory:  $DIR"
echo "Port:       $PORT"
echo

# 1. LLM context files
echo "-- setup-project.sh --"
"$DOTMDFILES/bin/setup-project.sh" "$DIR"
echo

# 2. launch-webterms.sh entry
if grep -q "restart_webterm $PORT " "$WEBTERMS"; then
  echo "-- launch-webterms.sh already has port $PORT, skipping --"
else
  echo "-- adding port $PORT to launch-webterms.sh --"
  # guard against a missing trailing newline gluing the new line onto the old one
  [ -z "$(tail -c1 "$WEBTERMS")" ] || printf '\n' >> "$WEBTERMS"
  printf 'restart_webterm %s %s\n' "$PORT" "$DIR" >> "$WEBTERMS"
fi
echo

# 3. project-home.html from template
HOME_HTML="$DIR/project-home.html"
if [ -e "$HOME_HTML" ]; then
  echo "-- $HOME_HTML already exists, skipping --"
else
  echo "-- generating $HOME_HTML --"
  sed \
    -e "s|PROJECT_NAME|$NAME|g" \
    -e "s|BASH_URL|http://127.0.0.1:$PORT/|g" \
    -e "s|CHATGPT_URL|https://chatgpt.com/|g" \
    -e "s|CLAUDE_URL|https://claude.ai/|g" \
    -e "s|GITHUB_URL|https://github.com/rtayek/$NAME|g" \
    "$MACRO" > "$HOME_HTML"
fi
echo

# 4. .envrc with PROJECT_TERMINAL_NAME
ENVRC="$DIR/.envrc"
if [ -e "$ENVRC" ]; then
  if grep -q PROJECT_TERMINAL_NAME "$ENVRC"; then
    echo "-- $ENVRC already sets PROJECT_TERMINAL_NAME, skipping --"
  else
    echo "-- appending PROJECT_TERMINAL_NAME to existing $ENVRC --"
    {
      printf 'PROJECT_TERMINAL_NAME=%s\n' "$NAME"
      echo 'export PROJECT_TERMINAL_NAME'
    } >> "$ENVRC"
  fi
else
  echo "-- generating $ENVRC --"
  cat > "$ENVRC" <<EOF
source ~/dotfiles/direnv/envrc
useProjectHistory
PROJECT_TERMINAL_NAME=$NAME
export PROJECT_TERMINAL_NAME
EOF
fi

echo
echo "Done. Remaining manual steps:"
echo "  - run 'direnv allow' in $DIR"
echo "  - add a Windows Terminal profile/color for $NAME"
echo "  - create a Chrome tab group and add $HOME_HTML as the anchor tab"
echo "  - commit and push the launch-webterms.sh change in dotfiles"
