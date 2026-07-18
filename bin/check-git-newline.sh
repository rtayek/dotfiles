
#!/bin/bash

# check-git-newlines.sh
# Find Git repos under a root folder and report:
#   - .gitattributes files
#   - .git/info/attributes
#   - local Git settings related to CRLF/LF
#   - tracked files containing carriage returns

ROOT="${1:-.}"

find "$ROOT" -type d -name .git -prune | while IFS= read -r GITDIR
do
    REPO=`dirname "$GITDIR"`

    echo
    echo "================================================================"
    echo "REPO: $REPO"
    echo "================================================================"

    cd "$REPO" || {
        echo "Could not cd into repo"
        continue
    }

    echo
    echo "---- local Git newline settings ----"
    LOCAL_SETTINGS=`git config --show-origin --local --list 2>/dev/null | grep -Ei 'autocrlf|eol|safecrlf|attributes'`

    if [ -n "$LOCAL_SETTINGS" ]; then
        echo "$LOCAL_SETTINGS"
    else
        echo "none"
    fi

    echo
    echo "---- repo .gitattributes files ----"
    ATTR_FILES=`find . -name .gitattributes -print`

    if [ -n "$ATTR_FILES" ]; then
        echo "$ATTR_FILES"
    else
        echo "none"
    fi

    echo
    echo "---- .git/info/attributes ----"
    if [ -f .git/info/attributes ]; then
        echo ".git/info/attributes exists"
        sed -n '1,120p' .git/info/attributes
    else
        echo "none"
    fi

    echo
    echo "---- tracked files containing CR ----"
    CR_FILES=`git grep -I -l "$(printf '\r')" -- . 2>/dev/null`

    if [ -n "$CR_FILES" ]; then
        echo "$CR_FILES"
    else
        echo "none"
    fi
done

