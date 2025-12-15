echo start ~ .bashrc

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Append to the history file instead of overwriting it
shopt -s histappend

# History configuration
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=20000

# History behavior
export HISTCONTROL=ignoredups:erasedups
export HISTIGNORE=$'[ \t]*:&:[fb]g:exit:ls'

# Path convenience from your original file
export qv="//sdcard/Download/videos"

# History sync across sessions:
#   history -a ? append new lines from this session
#   history -n ? read any new lines from other sessions
if [[ -n "$PROMPT_COMMAND" ]]; then
  PROMPT_COMMAND='history -a; history -n; '"$PROMPT_COMMAND"
else
  PROMPT_COMMAND='history -a; history -n'
fi
export PROMPT_COMMAND

# Load aliases if present
if [ -f "${HOME}/.bash_aliases" ]; then
   source "${HOME}/.bash_aliases"
fi

echo "adding conda."
. /c/Users/ray/miniconda3/etc/profile.d/conda.sh
echo "conda added."

gchat() {
  MSYS2_ARG_CONV_EXCL='*' cmd.exe /C "gemini"
}


