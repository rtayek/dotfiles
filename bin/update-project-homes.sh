#!/bin/sh
# Regenerate project-home.html for every registered project.
# Existing ChatGPT/Claude links are preserved when the registry fields are blank.

set -eu

PROJECTS_FILE="${PROJECTS_FILE:-$HOME/eclipse-workspace/dotmdfiles/projects.txt}"
MACRO="$HOME/dotfiles/templates/project-home.html.macro"

[ -f "$PROJECTS_FILE" ] || {
    echo "error: missing project registry: $PROJECTS_FILE" >&2
    exit 1
}
[ -f "$MACRO" ] || {
    echo "error: missing template: $MACRO" >&2
    exit 1
}

expand_home() {
    case "$1" in
        '~/'*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

existing_url() {
    file=$1
    host=$2
    [ -f "$file" ] || return 0
    sed -n "s|.*href=\"\([^\"]*$host[^\"]*\)\".*|\1|p" "$file" | head -n 1
}

while IFS='|' read -r name path port color chatgpt_url claude_url rest; do
    case "$name" in
        ''|'#'*) continue ;;
    esac
    [ -n "$port" ] || continue

    directory=$(expand_home "$path")
    if [ ! -d "$directory" ]; then
        echo "Skipping missing project directory: $directory" >&2
        continue
    fi

    home_html="$directory/project-home.html"

    if [ -z "$chatgpt_url" ]; then
        chatgpt_url=$(existing_url "$home_html" 'chatgpt.com')
    fi
    if [ -z "$claude_url" ]; then
        claude_url=$(existing_url "$home_html" 'claude.ai')
    fi

    [ -n "$chatgpt_url" ] || chatgpt_url='https://chatgpt.com/'
    [ -n "$claude_url" ] || claude_url='https://claude.ai/'

    github_url="https://github.com/rtayek/$name"
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT HUP INT TERM

    sed \
        -e "s|PROJECT_NAME|$name|g" \
        -e "s|BASH_URL|http://127.0.0.1:$port/|g" \
        -e "s|CHATGPT_URL|$chatgpt_url|g" \
        -e "s|CLAUDE_URL|$claude_url|g" \
        -e "s|GITHUB_URL|$github_url|g" \
        "$MACRO" > "$tmp"

    mv "$tmp" "$home_html"
    trap - EXIT HUP INT TERM
    echo "Updated $home_html"
done < "$PROJECTS_FILE"
