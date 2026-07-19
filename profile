export LANG=$(locale -uU)
# Only for interactive sh, not bash
[ -z "${BASH_VERSION-}" ] || return 0
[ -n "${PS1-}" ] || return 0

PS1='[sh] ${PWD##*/}$ '
