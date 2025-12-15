export LANG=$(locale -uU)

# POSIX prompt only for plain sh/dash
if [ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ] && [ -n "$PS1" ]; then
  PS1='[sh] \w$ '
fi
