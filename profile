echo "EXECUTING PROFILE. HOME=$HOME"
if locale -uU >/dev/null 2>&1; then
  export LANG=$(locale -uU)
elif [ -z "$LANG" ]; then
  export LANG=en_US.UTF-8
fi

case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) [ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH" ;;
esac

case ":$PATH:" in
  *":$HOME/dotfiles/bin:"*) ;;
  *) [ -d "$HOME/dotfiles/bin" ] && PATH="$HOME/dotfiles/bin:$PATH" ;;
esac

export PATH

[ -d "$HOME/man" ] && MANPATH="$HOME/man${MANPATH:+:$MANPATH}"
[ -d "$HOME/info" ] && INFOPATH="$HOME/info${INFOPATH:+:$INFOPATH}"
export MANPATH INFOPATH

export ENV="$HOME/dotfiles/sh/shrc"
export qv="//sdcard/Download/videos"

# Only for interactive sh, not bash
[ -z "${BASH_VERSION-}" ] || return 0
[ -n "${PS1-}" ] || return 0

PS1='[sh] ${PWD##*/}$ '
