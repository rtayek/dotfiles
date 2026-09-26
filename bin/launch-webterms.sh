#!/bin/sh

webterm="$HOME/bin/webterm.sh"
projectsFile=${projectsFile:-${PROJECTS_FILE:-"$HOME/.config/ray/projects.tsv"}}

expandHome() {
    case "$1" in
        "~/"*) printf '%s/%s\n' "$HOME" "${1#??}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

ensureWebterm() {
    port=$1
    directory=$2

    if netstat -ano 2>/dev/null |
        awk -v port=":$port" '
            $2 ~ port"$" && $4 == "LISTENING" {
                found=1
            }
            END { exit !found }
        '
    then
        echo "Port $port already listening; leaving it alone"
        return 0
    fi

    echo "Starting port $port in $directory"
    "$webterm" --detach --no-browser "$port" "$directory"
}

[ -f "$projectsFile" ] || {
    echo "error: missing project registry: $projectsFile" >&2
    exit 1
}

tab=$(printf '\t')
awk -F "$tab" 'NR > 1 { print $1 "|" $2 "|" $3 }' "$projectsFile" |
while IFS='|' read -r name path port; do
    [ -n "$port" ] || continue
    directory=$(expandHome "$path")
    ensureWebterm "$port" "$directory"
done
