#!/bin/sh
# Read-only audit of a Git repository's direnv/history/ignore/config/attributes setup.

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

expand_home_path() {
    case "$1" in
        '~/'*) printf '%s/%s\n' "$HOME" "${1#'~/'}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

show_config_key() {
    key=$1
    lines=$(git config --show-origin --get-all "$key" 2>/dev/null || true)
    if [ -n "$lines" ]; then
        printf '%s\n' "$lines" | sed 's/^/  /'
    else
        printf '  (not configured)\n'
    fi
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
    global_file=$(expand_home_path "$global")
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

section 'Git configuration / attributes'

printf 'Effective Git settings and their origins:\n'
for key in core.autocrlf core.safecrlf core.eol core.excludesfile core.attributesfile; do
    printf '%s:\n' "$key"
    show_config_key "$key"
done

local_overrides=
for key in core.autocrlf core.safecrlf core.eol core.excludesfile core.attributesfile; do
    value=$(git config --local --get-all "$key" 2>/dev/null || true)
    if [ -n "$value" ]; then
        if [ -z "$local_overrides" ]; then
            local_overrides=$key
        else
            local_overrides="$local_overrides $key"
        fi
        printf 'Repository-local override: %s=%s\n' "$key" "$(printf '%s' "$value" | tr '\n' ',')"
    fi
done
if [ -z "$local_overrides" ]; then
    printf 'Repository-local overrides of audited core settings: none\n'
fi

attributes=$(git config --get core.attributesfile 2>/dev/null || true)
attributes_file=
attributes_file_ok=0
attributes_has_text_auto=0
if [ -z "$attributes" ]; then
    printf 'core.attributesfile: NOT configured\n'
else
    attributes_file=$(expand_home_path "$attributes")
    printf 'Configured global attributes file: %s\n' "$attributes_file"
    if [ -f "$attributes_file" ]; then
        attributes_file_ok=1
        printf 'global attributes file: present\n'
        if grep -Eq '^[[:space:]]*\*[[:space:]]+text=auto([[:space:]]|$)' "$attributes_file"; then
            attributes_has_text_auto=1
            printf 'global text policy: * text=auto present\n'
        else
            printf 'NOTICE: global attributes file does not contain "* text=auto"\n'
        fi
    else
        printf 'WARNING: configured global attributes file does not exist\n'
    fi
fi

repo_attributes=$(find . -path './.git' -prune -o -type f -name .gitattributes -print)
if [ -z "$repo_attributes" ]; then
    printf 'Repository .gitattributes files: none\n'
else
    printf 'Repository .gitattributes files:\n'
    printf '%s\n' "$repo_attributes" | sed 's/^/  /'

    attribute_rules=$(find . -path './.git' -prune -o -type f -name .gitattributes -exec grep -HnE '(eol=(lf|crlf)|working-tree-encoding=|(^|[[:space:]])text(=auto)?([[:space:]]|$))' {} \; 2>/dev/null || true)
    if [ -n "$attribute_rules" ]; then
        printf 'Text / EOL / encoding rules found in repository attributes:\n'
        printf '%s\n' "$attribute_rules" | sed 's/^/  /'
    fi
fi

printf '\nAttribute probes (actual Git attribute behavior):\n'
for p in audit-probe.txt audit-probe.sh audit-probe.bat audit-probe.ps1 audit-probe.java audit-probe.md; do
    printf '  %s\n' "$p"
    probe=$(git check-attr text eol working-tree-encoding -- "$p" 2>/dev/null || true)
    if [ -n "$probe" ]; then
        printf '%s\n' "$probe" | sed 's/^/    /'
    else
        printf '    no attribute result\n'
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

if [ -z "$attributes" ]; then
    printf '%s\n' '- No global Git attributes file is configured.'
elif [ "$attributes_file_ok" -eq 0 ]; then
    printf '%s\n' '- core.attributesfile points to a file that does not exist.'
elif [ "$attributes_has_text_auto" -eq 0 ]; then
    printf '%s\n' '- Global attributes file is present but does not contain the expected "* text=auto" policy.'
else
    printf '%s\n' '- Global attributes file is present and contains "* text=auto".'
fi

if [ -n "$local_overrides" ]; then
    printf '%s\n' "- Repository-local Git core override(s) found: $local_overrides. Review only if behavior differs from the global policy."
else
    printf '%s\n' '- No repository-local overrides of the audited Git core settings.'
fi

if [ -n "$repo_attributes" ]; then
    printf '%s\n' '- Repository .gitattributes rules are present. These are valid project policy; review them only when line-ending or encoding behavior is surprising.'
else
    printf '%s\n' '- No repository-specific .gitattributes rules found.'
fi

printf '%s\n' '- This script is read-only; it changes nothing.'
