if [ -f "$HOME/dotfiles/shell/environment" ]; then
  . "$HOME/dotfiles/shell/environment"
elif [ -f "/home/${USER:-ray}/dotfiles/shell/environment" ]; then
  . "/home/${USER:-ray}/dotfiles/shell/environment"
fi

# Only for interactive sh, not bash
[ -z "${BASH_VERSION-}" ] || return 0
[ -n "${PS1-}" ] || return 0
PS1='[sh] ${PWD##*/}$ '
