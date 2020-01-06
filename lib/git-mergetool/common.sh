__exit_handlers=()

register_exit_handler() {
    local handler=$1
    __exit_handlers+=("$handler")
}

__exec_exit_handlers() {
    local i
    for (( i=0; i < ${#__exit_handlers[@]}; i++ )); do
        eval "${__exit_handlers[$(( ${#__exit_handlers[@]} - i-1 ))]}"
    done
}

trap __exec_exit_handlers EXIT ERR


__tmp_files=()

__remove_tmp_files() {
    if (( ${#__tmp_files[@]} )); then
        rm -rf -- "${__tmp_files[@]}"
    fi
}

register_tmp_file() {
    local file=$1
    __tmp_files+=("$file")
}

register_exit_handler __remove_tmp_files


# asks user to make a choice
# args:
#   prompt
#   choices: (optional) single-letter characters separated by /,
#     the default one is uppercased
# defaults to Y/n choices, in this case returns 0/1
# otherwise prints user choice (single lowercase letter)
ask() {
    local prompt=$1 choices=${2-}
    local char
    if [[ "$choices" ]]; then
        local _IFS=$IFS
        IFS=/
        local choices_arr=($choices)
        IFS=$_IFS

        while true; do
            read -rsN 1 -p "$prompt [$choices] " char

            # print user choice, possibly choosing the default one if user pressed Enter
            if [ "$char" = $'\n' ]; then
                # user pressed Enter, look for the default choice
                for choice in ${choices_arr[@]+"${choices_arr[@]}"}; do
                    if [ "$choice" != "${choice,,}" ]; then
                        printf "%s\n" "${choice,,}" >&2
                        char=${choice,,}
                        break;
                    fi
                done
            else
                printf "%s\n" "${char,,}" >&2
            fi

            # print the result
            for choice in ${choices_arr[@]+"${choices_arr[@]}"}; do
                if [ "${char,,}" = "${choice,,}" ]; then
                    printf "%s" "${char,,}"
                    return
                fi
            done
        done
    else
        read -rsN 1 -p "$prompt [Y/n] " char
        if [ "${char,,}" = y ] || [ "${char-}" = $'\n' ]; then
            echo yes >&2
            return 0
        else
            echo no >&2
            return 1
        fi
    fi
}
