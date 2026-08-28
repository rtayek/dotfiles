#!/bin/sh
# Report exact root .gitignore patterns already covered by the global Git ignore.
# Read-only: this script changes nothing.

set -u

show_all=0
directory=.

usage() {
    cat <<'EOF'
Usage: find-gitignore-duplicates.sh [--all] [directory]

Print exact non-comment patterns that appear in both:
  - Git's configured global ignore file, and
  - each repository's root .gitignore below directory.

By default, repositories below vendor/ are skipped because their ignore files
usually belong to upstream projects and should remain self-contained.

Options:
  --all       Include repositories below vendor/.
  -h, --help  Show this help.

The default directory is the current directory.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all)
            show_all=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            if [ "$#" -gt 0 ]; then
                directory=$1
                shift
            fi
            if [ "$#" -gt 0 ]; then
                printf 'error: too many arguments\n' >&2
                usage >&2
                exit 2
            fi
            break
            ;;
        -*)
            printf 'error: unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        *)
            directory=$1
            ;;
    esac
    shift
done

if [ ! -d "$directory" ]; then
    printf 'error: directory not found: %s\n' "$directory" >&2
    exit 2
fi

if ! command -v git >/dev/null 2>&1; then
    printf 'error: git not found on PATH\n' >&2
    exit 2
fi

root=$(cd "$directory" && pwd) || exit 2

global=$(git config --get core.excludesfile 2>/dev/null || true)
if [ -z "$global" ]; then
    printf 'error: core.excludesfile is not configured\n' >&2
    exit 2
fi

case "$global" in
    '~/'*) global_file=$HOME/${global#'~/'} ;;
    *) global_file=$global ;;
esac

if [ ! -f "$global_file" ]; then
    printf 'error: global ignore file does not exist: %s\n' "$global_file" >&2
    exit 2
fi

printf 'Global ignore: %s\n' "$global_file"
printf 'Scanning:      %s\n' "$root"
if [ "$show_all" -eq 0 ]; then
    printf 'Vendor repos:  skipped (use --all to include)\n'
else
    printf 'Vendor repos:  included\n'
fi

found=0

# Keep this loop in the current shell so "found" survives. A temporary list
# also avoids depending on non-POSIX process substitution.
tmp=${TMPDIR:-/tmp}/gitignore-duplicates.$$
trap 'rm -f "$tmp"' EXIT HUP INT TERM

find "$root" \
    -type d -path '*/.claude/worktrees' -prune -o \
    -type d -name .git -prune -print > "$tmp"

while IFS= read -r gitdir; do
    [ -n "$gitdir" ] || continue

    repo=${gitdir%/.git}

    if [ "$show_all" -eq 0 ]; then
        case "$repo" in
            */vendor/*) continue ;;
        esac
    fi

    ignore=$repo/.gitignore
    [ -f "$ignore" ] || continue

    duplicates=$(awk '
        function clean(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        NR == FNR {
            s = clean($0)
            if (s != "" && s !~ /^#/) global[s] = 1
            next
        }
        {
            s = clean($0)
            if (s != "" && s !~ /^#/ && (s in global))
                printf "  %d: %s\n", FNR, s
        }
    ' "$global_file" "$ignore")

    [ -n "$duplicates" ] || continue

    found=1
    case "$repo" in
        "$root") label=. ;;
        "$root"/*) label=${repo#"$root"/} ;;
        *) label=$repo ;;
    esac

    printf '\n%s/.gitignore\n' "$label"
    printf '%s\n' "$duplicates"
done < "$tmp"

printf '\n'
if [ "$found" -eq 0 ]; then
    printf 'No exact root .gitignore duplicates found.\n'
else
    printf 'Only exact duplicates are shown. Review before removing them.\n'
fi

rm -f "$tmp"
trap - EXIT HUP INT TERM
