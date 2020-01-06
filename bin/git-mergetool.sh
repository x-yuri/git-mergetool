#!/usr/bin/env bash
set -eu
SCRIPT=$(basename -- "$0")
DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$DIR/../lib/git-mergetool/common.sh"


usage() {
    cat >&2 <<EOF
Usage: $SCRIPT
EOF
}


while getopts ":h-:" option; do
    case $option in
    -)
        case "$OPTARG" in
        help)   usage
            exit;;
        *)   printf "%s\n" "$SCRIPT: unknown option: --$OPTARG" >&2
            usage
            exit 1;;
        esac;;
    h)   usage
        exit;;
    \?)   printf "%s\n" "$SCRIPT: unknown option: -$OPTARG" >&2
        usage
        exit 1;;
    :)   printf "%s\n" "$SCRIPT: option -$OPTARG requires an argument" >&2
        usage
        exit 1;;
    esac
done
shift $((OPTIND-1))


tmp=$(mktemp -d "/tmp/$SCRIPT.XXXXXX")   && register_tmp_file "$tmp"


repo_root=$(readlink -f -- "$(git rev-parse --show-toplevel)")
rel_path=
while [[ "$(readlink -f "${rel_path:-.}")" != "$repo_root" ]]; do
    rel_path=../${rel_path}
done

_IFS=$IFS
IFS=$'\n'
files=($(git diff --diff-filter=U --name-only))
IFS=$IFS
r=0
quit=0
for file in "${files[@]:+${files[@]}}"; do
    (( quit )) && break
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        cp -- "$rel_path$file" "$tmp"
    else
        printf "%s\n" "$rel_path$file:" >&2
    fi
    "$DIR/git-rebasediff.sh" -- "$rel_path$file"
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        if ! git show ":2:$rel_path$file" >/dev/null 2>&1 \
        || ! git show ":3:$rel_path$file" >/dev/null 2>&1; then
            deleted=1
        else
            deleted=0
        fi
        if (( ! deleted )) \
        && diff -- "$rel_path$file" "$tmp/$(basename -- "$file")" >/dev/null; then
            r=1
        else
            (( deleted )) && choices=Y/n/d/q || choices=Y/n/q
            answer=$(ask 'accept?' "$choices")
            if [[ "$answer" == y ]]; then
                git add -- "$rel_path$file"
            elif [[ "$answer" == d ]]; then
                git rm -- "$rel_path$file" >/dev/null
            else
                r=1
                if [[ "$answer" == q ]]; then
                    quit=1
                fi
            fi
        fi
        rm "$tmp/$(basename -- "$file")"
    else
        r=1
    fi
done

exit "$r"
