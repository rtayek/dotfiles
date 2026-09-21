#!/bin/sh

WEBTERM="$HOME/bin/webterm.sh"

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

ensure_webterm 1031 /c/Users/ray/dotfiles
ensure_webterm 1032 /c/Users/ray/eclipse-workspace/dotmdfiles
ensure_webterm 1033 /c/Users/ray/eclipse-workspace/chatmap
ensure_webterm 1034 /c/Users/ray/eclipse-workspace/five-rules
ensure_webterm 1035 /c/Users/ray/eclipse-workspace/system
ensure_webterm 1036 /c/Users/ray/eclipse-workspace/clipboard
ensure_webterm 1037 /c/Users/ray/eclipse-workspace/money
ensure_webterm 1038 /c/Users/ray/eclipse-workspace/openworker-eval-2026-09-1
