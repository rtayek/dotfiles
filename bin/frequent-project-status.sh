#!/bin/sh

projectsFile=${projectsFile:-${PROJECTS_FILE:-"$HOME/.config/ray/projects.tsv"}}

if [ ! -r "$projectsFile" ]; then
    printf 'error: cannot read project registry: %s\n' "$projectsFile" >&2
    exit 1
fi

expandHome() {
    case "$1" in
        "~/"*) printf '%s/%s\n' "$HOME" "${1#??}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

tab=$(printf '\t')
awk -F "$tab" 'NR > 1 { print $2 }' "$projectsFile" | (
    status=0
    while IFS= read -r projectValue; do
        project=$(expandHome "$projectValue")
        printf '=== %s ===\n' "$(basename "$project")"

        if [ ! -d "$project" ]; then
            printf 'missing: %s\n\n' "$project" >&2
            status=1
            continue
        fi

        if ! git -C "$project" status --short --branch; then
            status=1
        fi
        printf '\n'
    done
    exit "$status"
)
