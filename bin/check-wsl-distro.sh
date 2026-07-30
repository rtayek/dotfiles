cat > ~/bin/check-wsl-distro.sh <<'EOF'
#!/bin/sh

expected_distro=${RAY_EXPECTED_WSL_DISTRO:-${1:-}}

current_distro=${WSL_DISTRO_NAME:-}

if [ -z "$current_distro" ]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
        current_distro="WSL-unknown"
    else
        current_distro="not-WSL"
    fi
fi

command_location()
{
    command -v "$1" 2>/dev/null || printf '%s\n' "missing"
}

printf '%s\n' "Shell environment"
printf '%s\n' "-----------------"
printf 'Distro:        %s\n' "$current_distro"
printf 'HOME:          %s\n' "$HOME"
printf 'Tilde:         %s\n' "$HOME"
printf 'PWD:           %s\n' "$PWD"
printf 'Shell:         %s\n' "${SHELL:-unknown}"

if [ -d "$HOME/dotfiles" ]; then
    printf 'Dotfiles:      %s\n' "$HOME/dotfiles"
else
    printf '%s\n' "Dotfiles:      missing"
fi

printf 'OpenClaw:      %s\n' "$(command_location openclaw)"
printf 'Java:          %s\n' "$(command_location java)"
printf 'Gradle:        %s\n' "$(command_location gradle)"
printf 'Git:           %s\n' "$(command_location git)"

if [ -d "$HOME/dotfiles/.git" ]; then
    branch=$(git -C "$HOME/dotfiles" branch --show-current 2>/dev/null)
    printf 'Dotfiles git:  branch %s\n' "${branch:-unknown}"
elif [ -d "$HOME/dotfiles" ]; then
    printf '%s\n' "Dotfiles git:  directory exists, but is not a Git repository"
else
    printf '%s\n' "Dotfiles git:  missing"
fi

if [ -n "$expected_distro" ]; then
    printf 'Expected:      %s\n' "$expected_distro"

    if [ "$current_distro" != "$expected_distro" ]; then
        printf '\nWARNING: This is %s, not %s.\n' \
            "$current_distro" \
            "$expected_distro"
        exit 1
    fi

    printf '\nCorrect WSL distro.\n'
fi

exit 0
EOF

chmod 755 ~/bin/check-wsl-distro.sh