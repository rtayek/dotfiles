export LANG=$(locale -uU)
# Only for interactive sh, not bash
[ -n "${BASH_VERSION-}" ] && return 0
[ -n "${PS1-}" ] || return 0

PS1='[sh] ${PWD##*/}$ '

