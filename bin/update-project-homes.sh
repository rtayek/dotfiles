#!/bin/sh

set -eu

projectsFile=${projectsFile:-${PROJECTS_FILE:-"$HOME/.config/ray/projects.tsv"}}
macro="$HOME/dotfiles/templates/project-home.html.macro"

[ -f "$projectsFile" ] || {
    echo "error: missing project registry: $projectsFile" >&2
    exit 1
}
[ -f "$macro" ] || {
    echo "error: missing template: $macro" >&2
    exit 1
}

expandHome() {
    case "$1" in
        "~/"*) printf '%s/%s\n' "$HOME" "${1#??}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

existingUrl() {
    file=$1
    host=$2
    [ -f "$file" ] || return 0
    sed -n "s|.*href=\"\([^\"]*$host[^\"]*\)\".*|\1|p" "$file" | head -n 1
}

tab=$(printf '\t')
awk -F "$tab" 'NR > 1 { print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 }' "$projectsFile" |
while IFS='|' read -r name path port color chatgptUrl claudeUrl; do
    [ -n "$port" ] || continue

    directory=$(expandHome "$path")
    if [ ! -d "$directory" ]; then
        echo "Skipping missing project directory: $directory" >&2
        continue
    fi

    homeHtml="$directory/project-home.html"

    if [ -z "$chatgptUrl" ]; then
        chatgptUrl=$(existingUrl "$homeHtml" 'chatgpt.com')
    fi
    if [ -z "$claudeUrl" ]; then
        claudeUrl=$(existingUrl "$homeHtml" 'claude.ai')
    fi

    [ -n "$chatgptUrl" ] || chatgptUrl='https://chatgpt.com/'
    [ -n "$claudeUrl" ] || claudeUrl='https://claude.ai/'

    githubUrl="https://github.com/rtayek/$name"
    tempFile=$(mktemp)
    trap 'rm -f "$tempFile"' 0 1 2 15

    sed \
        -e "s|PROJECT_NAME|$name|g" \
        -e "s|BASH_URL|http://127.0.0.1:$port/|g" \
        -e "s|CHATGPT_URL|$chatgptUrl|g" \
        -e "s|CLAUDE_URL|$claudeUrl|g" \
        -e "s|GITHUB_URL|$githubUrl|g" \
        "$macro" > "$tempFile"

    mv "$tempFile" "$homeHtml"
    trap - 0 1 2 15
    echo "Updated $homeHtml"
done
