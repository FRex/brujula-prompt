#!/bin/bash

function __brujula_print_deleted_pwd() {
    # amount of iterations, could come from an env var later
    # delete dir is a bad case so set a very high limit here
    local x=240
    local p="$PWD"

    # c like for loop allows $x, {1..24} syntax wouldn't
    for ((i = 0; i < x; i++)); do
        if [ -d "$p" ]; then
            local path2=${PWD#"$p"}
            local path1=${PWD%"$path2"}
            [[ $path1 == $HOME* ]] && path1="${path1//"$HOME"/'~'}"
            echo -e "\u001b[33m$path1\u001b[0m\u001b[31m$path2\u001b[0m"
            break
        fi

        # cut off one /dir off the end of the path
        p=${p%/*}

        # strange case, can happen with git bash and deleted ramdisk on windows
        if [ -z "$p" ]; then
            echo -e "\u001b[31m$PWD\u001b[0m"
            break
        fi
    done
}

function __brujula_prompt() {
    local laststatus="$?"

    if [ $laststatus -eq 0 ]; then
        local lastcommandstatus="\u001b[32m$laststatus\u001b[0m"
    else
        local lastcommandstatus="\u001b[31m$laststatus\u001b[0m"
    fi

    local hiddenfiles=(.*)
    local hiddenfilescount="${#hiddenfiles[@]}"

    # each dir has itself . and parent dir .. so less than 2 hidden files = deleted dir
    if [[ "$hiddenfilescount" -lt 2 ]]; then
        __brujula_print_deleted_pwd
        return
    fi

    local normalfiles=(*)
    local normalfilescount="${#normalfiles[@]}"

    # if nullglob is enabled then count is 0 and we return it directly in else
    # but if its disabled (by default its disabled) then for empty dirs we
    # end up with a 1 element array with '*' in it, so this check catches that
    # and returns 0 as well, we cant just compare 1 element array to '*'
    # because that would break for dir with single file named '*' in it
    if [[ "$normalfilescount" -eq 1 && ! -e "${normalfiles[0]}" ]]; then
        normalfilescount=0
    fi

    local p="$PWD"

    # amount of iterations, could come from an env var later
    local x=24

    # c like for loop allows $x, {1..24} syntax wouldn't
    local i
    for ((i = 0; i < x; i++)); do
        # print yellow path if we reached the root
        if [[ -z "$p" ]]; then
            local path1="$PWD"
            [[ $path1 == $HOME* ]] && path1="${path1//"$HOME"/'~'}"
            echo -e "\u001b[33m$path1\u001b[0m $normalfilescount.$hiddenfilescount $lastcommandstatus"
            break
        fi

        # does git head exist
        if [[ -f "$p/.git/HEAD" ]]; then
            # read its only line with no external processes if yes
            read -r line <"$p/.git/HEAD"

            # strip the ref prefix if needed
            local trimmedline=${line#ref: refs/heads/}

            # prepare the to repo and in repo paths
            local path2=${PWD#"$p"}
            local path1=${PWD%"$path2"}

            # make in repo path single slash instead of nothing if in repo root dir
            if [[ -z "$path2" ]]; then
                local path2='/'
            fi

            [[ $path1 == $HOME* ]] && path1="${path1//"$HOME"/'~'}"

            # print them in different colors
            local fullpath="\u001b[33m$path1\u001b[0m\u001b[32m$path2\u001b[0m"

            local hiddenfiles=(.*)

            # if we stripped ref prefix its a branch HEAD, else its commit
            if [[ "$trimmedline" != "$line" ]]; then
                echo -e "$fullpath $normalfilescount.$hiddenfilescount \u001b[36m($trimmedline)\u001b[0m $lastcommandstatus"
            else
                echo -e "$fullpath $normalfilescount.$hiddenfilescount \u001b[32m($trimmedline)\u001b[0m $lastcommandstatus"
            fi
            break
        fi

        # cut off one /dir off the end of the path
        p=${p%/*}
    done
}

# for development only (to run without sourcing):
if [[ "$1" == "run" ]]; then
    function __brujula_run() {
        local before now total reps i
        before=${EPOCHREALTIME/./}
        total=0
        reps=125
        for ((i = 0; i < reps; i++)); do
            __brujula_prompt
            now=${EPOCHREALTIME/./}
            total="$((total + now - before))"
            echo "$((now - before)) microseconds"
            before="$now"
        done
        echo "$((total / reps)) microseconds average"
    }

    __brujula_run
fi
