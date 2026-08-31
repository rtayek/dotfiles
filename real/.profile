case "${RAY_DOTFILES_UNAME_S:-$(uname -s 2>/dev/null || printf unknown)}" in
  Linux*)
    __ray_stub_home="${RAY_DOTFILES_LINUX_HOME:-/home/${USER:-ray}}"
    if [ -f "$__ray_stub_home/dotfiles/profile" ]; then
      . "$__ray_stub_home/dotfiles/profile"
      __ray_stub_loaded=1
    fi
    ;;
esac

if [ -z "${__ray_stub_loaded-}" ] && [ -f "$HOME/dotfiles/profile" ]; then
  . "$HOME/dotfiles/profile"
fi

unset __ray_stub_home __ray_stub_loaded
