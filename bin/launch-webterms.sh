#!/bin/sh

WEBTERM="$HOME/bin/webterm.sh"

restart_webterm() {
    port=$1
    directory=$2

    pid=$(
        netstat -ano 2>/dev/null |
        awk -v port=":$port" '
            $2 ~ port"$" && $4 == "LISTENING" {
                print $5
                exit
            }'
    )

    if [ -n "$pid" ]; then
        echo "Stopping old web terminal on port $port"
        MSYS2_ARG_CONV_EXCL='*' taskkill.exe /PID "$pid" /F >/dev/null 2>&1
    fi

    echo "Starting port $port in $directory"
    "$WEBTERM" --detach --no-browser "$port" "$directory"
}

restart_webterm 1031 /c/Users/ray/dotfiles
restart_webterm 1032 /c/Users/ray/eclipse-workspace/dotmdfiles
restart_webterm 1033 /c/Users/ray/eclipse-workspace/chatmap