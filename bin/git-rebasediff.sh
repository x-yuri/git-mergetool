#!/usr/bin/env bash
set -eu
SCRIPT=$(basename -- "$0")
DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$DIR/../lib/git-mergetool/common.sh"

usage() {
    cat >&2 <<EOF
Usage: $SCRIPT FILE
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

if (( $# < 1 )); then
    printf "%s\n" "$SCRIPT: specify path to file" >&2
    usage
    exit 1
fi
P_PATH=$1

repo_root=$(git rev-parse --show-toplevel)
dir=${PWD:${#repo_root} + 1}
dir=${dir:+$dir/}

cd "$repo_root"
fname=$(basename -- "$dir$P_PATH")
fpath=$(readlink -f -- "$dir$P_PATH")
fpath=${fpath:${#repo_root} + 1}

tmp_local=$(mktemp "/tmp/$fname.LOCAL.XXXXXX")   && register_tmp_file "$tmp_local"
git show ":2:$fpath" >"$tmp_local" 2>/dev/null || true
tmp_base=$(mktemp "/tmp/$fname.BASE.XXXXXX")   && register_tmp_file "$tmp_base"
git show ":1:$fpath" >"$tmp_base" 2>/dev/null || true
tmp_remote=$(mktemp "/tmp/$fname.REMOTE.XXXXXX")   && register_tmp_file "$tmp_remote"
git show ":3:$fpath" >"$tmp_remote" 2>/dev/null || true

tab_cmds=()
if [[ -s "$tmp_local" ]]; then
    if [[ -s "$tmp_base" ]]; then
        tab_cmds+=("e $tmp_local | vertical rightbelow diffsplit $tmp_base")
    else
        tab_cmds+=("e $tmp_local")
    fi
fi
if [[ -s "$tmp_remote" ]]; then
    if [[ -s "$tmp_base" ]]; then
        tab_cmds+=("e $tmp_base | vertical rightbelow diffsplit $tmp_remote")
    else
        tab_cmds+=("e $tmp_remote")
    fi
fi
tab_cmds+=("e $fpath")

new_tab_cmd=' | tabnew | '
cmd=$(printf -- "$new_tab_cmd%s" "${tab_cmds[@]}")' | tabnext'
cmd=${cmd:${#new_tab_cmd}}

vimdiff "+$cmd"
