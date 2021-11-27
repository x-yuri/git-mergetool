#!/usr/bin/env bats
DIR=`readlink -f .`

load bats-mock/stub

one_line() {
    echo "$1" | tr $'\n' ' '
}

set_up_git_repo() {
    tmp=`mktemp -d`; cd "$tmp"
    git init
}

git_commit() {
    git add "${@:2}"
    git commit -m "$1"
}

git_delete() {
    git rm "${@:2}"
    git commit -m "$1"
}

git_status() {
    git log --oneline --decorate --graph --all
    git status
    git diff
}

unrand_filenames() {
    sed -E 's#(/tmp/[^ ]+\.(LOCAL|BASE|REMOTE))[^ ]+#\1#g'
}

vimdiff_cmd() {
    local r=(
        e "/tmp/$1"
    )
    if [ "$2" ]; then
        r+=(
            \| vertical rightbelow diffsplit "/tmp/$2"
        )
    fi
    shift 2
    if [ ${#@} = 3 ]; then
        r+=(
            \| tabnew
            \| e "/tmp/$1"
        )
        if [ "$2" ]; then
            r+=(
                \| vertical rightbelow diffsplit "/tmp/$2"
            )
        fi
        shift 2
    fi
    r+=(
        \| tabnew
        \| e "$1"
        \| tabnext
    )
    echo "+${r[*]}"
}

cat_files_oneliner() {
    echo "$(one_line '
        echo "$*"
        | sed "s/ | /\n/g"
        | sed -E "
            /.*(e|split|tabnew) ([^ ]+)/!d
            ; /.*(e|split|tabnew) ([^ ]+)/   s/.*(e|split|tabnew) ([^ ]+)/\2/"
        | while IFS= read -r; do
            cat "$REPLY"
        ; done
    ')"
}

output_args_oneliner() {
    echo 'for a; do echo "$a"; done'
}

mk_script() {
    tmp_script=`mktemp`
    cat > "$tmp_script"
    chmod u+x "$tmp_script"
    echo "$tmp_script"
}

swap_lines=$(mk_script <<\SCRIPT
#!/usr/bin/env bash
sed -Ei -e '/pick.*/!d' -e 'N; s/(.*)\n(.*)/\2\n\1/' "$1"
SCRIPT
)

@test "both modified" {
    stub vimdiff 'for a; do echo "$a"; done'
    tmp=`mktemp -d`; cd "$tmp"
    git init
    echo 1 > 1; git_commit m1 1
    git co -b devel
    echo 1d > 1; git_commit d2 1
    git co master
    echo 1m > 1; git_commit m2 1
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    output=$(echo "$output" | unrand_filenames)
    files=(1.LOCAL 1.BASE 1.BASE 1.REMOTE 1)
    [ "$output" == "$(vimdiff_cmd "${files[@]}")" ]
}

@test "deleted by us" {
    stub vimdiff 'for a; do echo "$a"; done'
    tmp=`mktemp -d`; cd "$tmp"
    git init
    echo 1 > 1; git_commit m1 1
    git co -b devel
    git_delete 'd2' 1
    git co master
    echo 1m > 1; git_commit m2 1
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    output=$(echo "$output" | unrand_filenames)
    files=(1.BASE 1.REMOTE 1)
    [ "$output" == "$(vimdiff_cmd "${files[@]}")" ]
}

@test "deleted by them" {
    stub vimdiff 'for a; do echo "$a"; done'
    tmp=`mktemp -d`; cd "$tmp"
    git init
    echo 1 > 1; git_commit m1 1
    git co -b devel
    echo 1d > 1; git_commit d2 1
    git co master
    git_delete 'm2' 1
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    output=$(echo "$output" | unrand_filenames)
    files=(1.LOCAL 1.BASE 1)
    [ "$output" == "$(vimdiff_cmd "${files[@]}")" ]
}

@test "both added" {
    stub vimdiff 'for a; do echo "$a"; done'
    tmp=`mktemp -d`; cd "$tmp"
    git init
    echo 1 > 1; git_commit m1 1
    git co -b devel
    echo 2d > 2; git_commit d2 2
    git co master
    echo 2m > 2; git_commit m2 2
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 2

    [ "$status" = 0 ]
    output=$(echo "$output" | unrand_filenames)
    files=(2.LOCAL '' 2.REMOTE '' 2)
    [ "$output" == "$(vimdiff_cmd "${files[@]}")" ]
}

set_up_merge_conflict() {
    set_up_git_repo
    echo 1 > 1; git_commit c1 1
    echo 2 > 1; git_commit c2 1
    echo 3 > 1; git_commit c3 1
    EDITOR="$swap_lines" git rebase -i HEAD~2 || true
}

@test "merge conflict: filenames" {
    set_up_merge_conflict
    stub vimdiff "$(output_args_oneliner)"

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    output=$(echo "$output" | unrand_filenames)
    files=(1.LOCAL 1.BASE 1.BASE 1.REMOTE 1)
    [ "$output" == "$(vimdiff_cmd "${files[@]}")" ]
}

@test "merge conflict: file content" {
    set_up_merge_conflict
    stub vimdiff "$(cat_files_oneliner)"

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    [ "$output" = 1$'\n'2$'\n'2$'\n'3$'\n'"$(cat 1)" ]
}

@test "no filename passed" {
    run "$DIR/bin/git-rebasediff.sh"

    [ "$status" = 1 ]
    [[ "$output" =~ "specify path to file" ]]
    [[ "$output" =~ "Usage" ]]
}

teardown() {
    unstub vimdiff
    [ "${tmp:-}" ] && rm -rf "$tmp" || true
    [ "${tmp_script:-}" ] && rm -rf "$tmp_script" || true
}
