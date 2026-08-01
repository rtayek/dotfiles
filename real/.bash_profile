case "${RAY_DOTFILES_UNAME_S:-$(uname -s 2>/dev/null || printf unknown)}" in
  Linux*)
    __ray_stub_home="${RAY_DOTFILES_LINUX_HOME:-/home/${USER:-ray}}"
    if [ -f "$__ray_stub_home/dotfiles/bash/bash_profile" ]; then
      . "$__ray_stub_home/dotfiles/bash/bash_profile"
      __ray_stub_loaded=1
    fi
    ;;
esac

if [ -z "${__ray_stub_loaded-}" ] && [ -f "$HOME/dotfiles/bash/bash_profile" ]; then
  . "$HOME/dotfiles/bash/bash_profile"
fi

unset __ray_stub_home __ray_stub_loaded
