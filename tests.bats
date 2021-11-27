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

output_both() {
    echo "$(one_line '
        cmd=$1;
        echo "$cmd"
            | sed -E "s/^\+//; s/\|/\n/g"
            | egrep -v "^\s*(tabnew|tabnext)\s*$"
            | awk "{print \$NF}"
            | while IFS= read -r f; do
                echo "$(basename -- "$f" | sed -E "s/(\\.(LOCAL|BASE|REMOTE)).*/\\1/"):";
                cat "$f" | sed -E "s/^/    /";
            done
    ')"
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

strip_commit_hash() {
    sed -E 's/(>>>>>>>) [0-9a-f]+/\1/'
}

@test "both modified" {
    stub vimdiff "$(output_both)"
    set_up_git_repo
    echo 1 > 1; git_commit c1 1
    git checkout -b devel
    echo 1d > 1; git_commit d2 1
    git checkout master
    echo 1m > 1; git_commit m2 1
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    expected_output=$(cat <<OUTPUT
1.LOCAL:
    1d
1.BASE:
    1
1.BASE:
    1
1.REMOTE:
    1m
1:
    <<<<<<< HEAD
    1d
    =======
    1m
    >>>>>>> (m2)
OUTPUT
)
    output=`echo "$output" | strip_commit_hash`
    [ "$output" == "$expected_output" ]
}

@test "deleted by us" {
    stub vimdiff "$(output_both)"
    set_up_git_repo
    echo 1 > 1; git_commit c1 1
    git checkout -b devel
    git_delete 'd2' 1
    git checkout master
    echo 1m > 1; git_commit m2 1
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    expected_output=$(cat <<OUTPUT
1.BASE:
    1
1.REMOTE:
    1m
1:
    1m
OUTPUT
)
    [ "$output" == "$expected_output" ]
}

@test "deleted by them" {
    stub vimdiff "$(output_both)"
    set_up_git_repo
    echo 1 > 1; git_commit c1 1
    git checkout -b devel
    echo 1d > 1; git_commit d2 1
    git checkout master
    git_delete 'm2' 1
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    expected_output=$(cat <<OUTPUT
1.LOCAL:
    1d
1.BASE:
    1
1:
    1d
OUTPUT
)
    [ "$output" == "$expected_output" ]
}

@test "both added" {
    stub vimdiff "$(output_both)"
    set_up_git_repo
    echo 1 > 1; git_commit c1 1
    git checkout -b devel
    echo 2d > 2; git_commit d2 2
    git checkout master
    echo 2m > 2; git_commit m2 2
    git rebase devel || true

    run "$DIR/bin/git-rebasediff.sh" 2

    [ "$status" = 0 ]
    output=`echo "$output" | strip_commit_hash`
    expected_output=$(cat <<OUTPUT
2.LOCAL:
    2d
2.REMOTE:
    2m
2:
    <<<<<<< HEAD
    2d
    =======
    2m
    >>>>>>> (m2)
OUTPUT
)
    [ "$output" == "$expected_output" ]
}

@test "swap commits" {
    set_up_git_repo
    echo 1 > 1; git_commit c1 1
    echo 2 > 1; git_commit c2 1
    echo 3 > 1; git_commit c3 1
    EDITOR="$swap_lines" git rebase -i HEAD~2 || true
    stub vimdiff "$(output_both)"

    run "$DIR/bin/git-rebasediff.sh" 1

    [ "$status" = 0 ]
    output=`echo "$output" | strip_commit_hash`
    expected_output=$(cat <<OUTPUT
1.LOCAL:
    1
1.BASE:
    2
1.BASE:
    2
1.REMOTE:
    3
1:
    <<<<<<< HEAD
    1
    =======
    3
    >>>>>>> (c3)
OUTPUT
)
    [ "$output" == "$expected_output" ]
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
