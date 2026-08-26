#!/bin/sh
# Read-only audit of a Git repository's direnv/history/ignore setup.

set -u

repo=${1:-.}

if ! root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null); then
    printf 'error: not inside a Git working tree: %s\n' "$repo" >&2
    exit 2
fi

cd "$root" || exit 2

printf 'Repository: %s\n' "$root"
printf 'Branch:     %s\n' "$(git branch --show-current 2>/dev/null || printf '?')"
printf '\n'

tracked() {
    git ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

ignored_by() {
    git check-ignore -v --no-index -- "$1" 2>/dev/null || true
}

section() {
    printf '\n== %s ==\n' "$1"
}

section '.envrc / direnv'

if [ -f .envrc ]; then
    printf '.envrc: present'
    if tracked .envrc; then
        printf ', tracked\n'
    else
        printf ', NOT tracked\n'
    fi

    if grep -Eq '(^|[[:space:]])(source|\.)[[:space:]].*direnv/envrc' .envrc; then
        printf '  shared helper library: sourced\n'
    else
        printf '  shared helper library: not detected\n'
    fi

    for helper in useProjectHistory loadCentralSecrets loadSecretsIfPresent useJava useJavaFromFile useGradleCacheLocal useGradleCacheShared useNodeBin; do
        if grep -Eq "(^|[[:space:]])${helper}([[:space:]]|$)" .envrc; then
            printf '  helper requested: %s\n' "$helper"
        fi
    done

    if grep -Eq '(^|[[:space:]])useProjectHistory([[:space:]]|$)' .envrc; then
        printf '  history policy: project history explicitly enabled\n'
    else
        printf '  history policy: project history NOT enabled\n'
    fi

    if grep -Eq '(^|[[:space:]])(loadCentralSecrets|loadSecretsIfPresent)([[:space:]]|$)' .envrc; then
        printf '  secrets policy: explicitly enabled for this project\n'
    else
        printf '  secrets policy: not enabled (normal for projects that need no API keys)\n'
    fi
else
    printf '.envrc: absent\n'
    printf '  If this project should have separate Bash history, it needs a small tracked .envrc.\n'
fi

nested_envrc=$(find . -path './.git' -prune -o -type f -name .envrc ! -path './.envrc' -print)
if [ -n "$nested_envrc" ]; then
    printf 'Nested .envrc files found:\n%s\n' "$nested_envrc" | sed '2,$s/^/  /'
else
    printf 'Nested .envrc files: none\n'
fi

if [ -d direnv ]; then
    printf 'direnv/: present'
    if git ls-files -- direnv | grep -q .; then
        printf ', contains tracked files\n'
    else
        printf ', no tracked files\n'
    fi
    if [ -f direnv/envrc ]; then
        printf '  direnv/envrc helper library: present\n'
    fi
else
    printf 'direnv/: absent (normal for ordinary projects; dotfiles owns the shared helper library)\n'
fi

if [ -d .direnv ]; then
    printf '.direnv/: generated state is present\n'
    if git ls-files -- .direnv | grep -q .; then
        printf '  WARNING: .direnv contains tracked files\n'
    fi
    ignored=$(ignored_by .direnv/)
    if [ -n "$ignored" ]; then
        printf '  ignore rule: %s\n' "$ignored"
    else
        printf '  WARNING: .direnv/ is not ignored\n'
    fi
else
    printf '.direnv/: absent\n'
fi

section 'Bash history files'

histories=$(find . -path './.git' -prune -o -type f -name .bash_history -print)
if [ -z "$histories" ]; then
    printf 'No .bash_history files found in the repository.\n'
else
    printf '%s\n' "$histories" | while IFS= read -r p; do
        [ -n "$p" ] || continue
        case "$p" in
            ./.bash_history) kind='root (expected when project history is enabled)' ;;
            *) kind='NESTED (usually stale/unwanted)' ;;
        esac
        printf '%s: %s\n' "$p" "$kind"
        rel=${p#./}
        if tracked "$rel"; then
            printf '  WARNING: tracked by Git\n'
        fi
        why=$(ignored_by "$rel")
        if [ -n "$why" ]; then
            printf '  ignored by: %s\n' "$why"
        else
            printf '  WARNING: not ignored\n'
        fi
    done
fi

section 'Git ignore configuration'

global=$(git config --get core.excludesfile 2>/dev/null || true)
if [ -z "$global" ]; then
    printf 'core.excludesfile: NOT configured\n'
    global_file=
else
    printf 'core.excludesfile: %s\n' "$global"
    case "$global" in
        '~/'*) global_file=$HOME/${global#'~/'} ;;
        *) global_file=$global ;;
    esac
    if [ -f "$global_file" ]; then
        printf 'global ignore file: present (%s)\n' "$global_file"
    else
        printf 'WARNING: configured global ignore file does not exist: %s\n' "$global_file"
        global_file=
    fi
fi

ignore_files=$(find . -path './.git' -prune -o -type f -name .gitignore -print)
if [ -z "$ignore_files" ]; then
    printf 'Repository .gitignore files: none\n'
else
    printf 'Repository .gitignore files:\n'
    printf '%s\n' "$ignore_files" | sed 's/^/  /'
fi

if [ -n "${global_file:-}" ] && [ -f .gitignore ]; then
    printf '\nExact non-comment patterns duplicated in root .gitignore and global ignore:\n'
    duplicates=$(awk '
        function clean(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        NR==FNR {
            s=clean($0)
            if (s != "" && s !~ /^#/) global[s]=1
            next
        }
        {
            s=clean($0)
            if (s != "" && s !~ /^#/ && (s in global)) print s
        }
    ' "$global_file" .gitignore)
    if [ -n "$duplicates" ]; then
        printf '%s\n' "$duplicates" | sed 's/^/  DUPLICATE: /'
    else
        printf '  none\n'
    fi
fi

negations=$(find . -path './.git' -prune -o -type f -name .gitignore -exec grep -Hn '^[[:space:]]*!' {} \; 2>/dev/null || true)
if [ -n "$negations" ]; then
    printf '\nNegation rules found (worth reviewing because they can override broader ignores):\n'
    printf '%s\n' "$negations" | sed 's/^/  /'
fi

printf '\nPolicy probes (actual Git ignore behavior):\n'
for p in .bash_history subdir/.bash_history .env .project .classpath .settings/example build/example .gradle/example; do
    why=$(ignored_by "$p")
    if [ -n "$why" ]; then
        printf '  %-24s IGNORED  %s\n' "$p" "$why"
    else
        printf '  %-24s visible to Git\n' "$p"
    fi
done

section 'Summary / things to review'

if [ ! -f .envrc ]; then
    printf '%s\n' '- No root .envrc. Add one if separate project Bash history is desired.'
elif ! grep -Eq '(^|[[:space:]])useProjectHistory([[:space:]]|$)' .envrc; then
    printf '%s\n' '- .envrc exists but does not request project Bash history.'
fi

nested_histories=$(find . -path './.git' -prune -o -type f -name .bash_history ! -path './.bash_history' -print)
if [ -n "$nested_histories" ]; then
    count=$(printf '%s\n' "$nested_histories" | wc -l | tr -d ' ')
    printf '%s\n' "- $count nested .bash_history file(s) should be inspected and probably removed."
else
    printf '%s\n' '- No nested .bash_history files found.'
fi

if [ -n "${global_file:-}" ] && [ -f .gitignore ]; then
    if [ -n "${duplicates:-}" ]; then
        printf '%s\n' '- Root .gitignore duplicates some global patterns; review whether those duplicates are deliberate shared repo policy.'
    else
        printf '%s\n' '- Root .gitignore has no exact duplication with the global ignore file.'
    fi
fi

if [ -d .direnv ] && [ -z "$(ignored_by .direnv/)" ]; then
    printf '%s\n' '- .direnv/ exists but is not ignored.'
fi

printf '%s\n' '- This script is read-only; it changes nothing.'
