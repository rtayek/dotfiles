[ -f "$HOME/dotfiles/shell/environment" ] && . "$HOME/dotfiles/shell/environment"

# Only for interactive sh, not bash
[ -z "${BASH_VERSION-}" ] || return 0
[ -n "${PS1-}" ] || return 0
PS1='[sh] ${PWD##*/}$ '
