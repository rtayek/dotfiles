#!/bin/sh

WEBTERM="$HOME/bin/webterm.sh"
PROJECTS_FILE="${PROJECTS_FILE:-$HOME/eclipse-workspace/dotmdfiles/projects.txt}"

expand_home() {
    case "$1" in
        '~/'*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

ensure_webterm() {
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
    "$WEBTERM" --detach --no-browser "$port" "$directory"
}

[ -f "$PROJECTS_FILE" ] || {
    echo "error: missing project registry: $PROJECTS_FILE" >&2
    exit 1
}

while IFS='|' read -r name path port color rest; do
    case "$name" in
        ''|'#'*) continue ;;
    esac
    [ -n "$port" ] || continue
    directory=$(expand_home "$path")
    ensure_webterm "$port" "$directory"
done < "$PROJECTS_FILE"
