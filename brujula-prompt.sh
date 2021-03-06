#!/bin/bash

function __brujula_replace_home_prefix() {
    # if string starts with $HOME then replace first occurence of $HOME with ~
    # this is to prevent paths like /x/y/home/name from being affected
    if [[ $1 =~ ^$HOME.* ]]
    then
        echo "${1//"$HOME"/'~'}"
    else
        echo "$1"
    fi
}

function __brujula_countfiles() {
    local normalfiles=(*)
    local count="${#normalfiles[@]}"

    # if nullglob is enabled then count is 0 and we return it directly in else
    # but if its disabled (by default its disabled) then for empty dirs we
    # end up with a 1 element array with '*' in it, so this check catches that
    # and returns 0 as well, we cant just compare 1 element array to '*'
    # because that would break for dir with single file named '*' in it
    if [[ "$count" -eq 1 && ! -e "${normalfiles[0]}" ]]
    then
        echo 0
    else
        echo "$count"
    fi
}

function __brujula_print_deleted_pwd() {
    # amount of iterations, could come from an env var later
    # delete dir is a bad case so set a very high limit here
    local x=240
    local p="$PWD"

   # c like for loop allows $x, {1..24} syntax wouldn't
    for (( i=0 ; i<x ; i++ ))
    do
        if [ -d "$p" ]
        then
            local path2=${PWD#"$p"}
            local path1=${PWD%"$path2"}
            path1=$(__brujula_replace_home_prefix "$path1")
            echo -e "\u001b[33m$path1\u001b[0m\u001b[31m$path2\u001b[0m"
            break
        fi

        # cut off one /dir off the end of the path
        p=${p%/*}

        # strange case, can happen with git bash and deleted ramdisk on windows
        if [ -z "$p" ]
        then
            echo -e "\u001b[31m$PWD\u001b[0m"
            break
        fi
    done
}

function __brujula_prompt() {
    local hiddenfiles=(.*)

    if [[ "${#hiddenfiles[@]}" -lt 2 ]]
    then
        __brujula_print_deleted_pwd
        return
    fi


    local p="$PWD"

    # amount of iterations, could come from an env var later
    local x=24

    # c like for loop allows $x, {1..24} syntax wouldn't
    for (( i=0 ; i<x ; i++ ))
    do
        # print yellow path if we reached the root
        if [[ -z "$p" ]]
        then
            local path1
            path1=$(__brujula_replace_home_prefix "$PWD")
            echo -e "\u001b[33m$path1\u001b[0m $(__brujula_countfiles).${#hiddenfiles[@]}"
            break
        fi

        # does git head exist
        if [[ -f "$p/.git/HEAD" ]]
        then
            # read its only line with no external processes if yes
            read -r line < "$p/.git/HEAD"

            # strip the ref prefix if needed
            local trimmedline=${line#ref: refs/heads/}

            # prepare the to repo and in repo paths
            local path2=${PWD#"$p"}
            local path1=${PWD%"$path2"}

            # make in repo path single slash instead of nothing if in repo root dir
            if [[ -z "$path2" ]]
            then
                local path2='/'
            fi

            path1=$(__brujula_replace_home_prefix "$path1")

            # print them in different colors
            local fullpath="\u001b[33m$path1\u001b[0m\u001b[32m$path2\u001b[0m"

            local hiddenfiles=(.*)

            # if we stripped ref prefix its a branch HEAD, else its commit
            if [[ "$trimmedline" != "$line" ]]
            then
                echo -e "$fullpath $(__brujula_countfiles).${#hiddenfiles[@]} \u001b[36m($trimmedline)\u001b[0m"
            else
                echo -e "$fullpath $(__brujula_countfiles).${#hiddenfiles[@]} \u001b[32m($trimmedline)\u001b[0m"
            fi
            break
        fi

        # cut off one /dir off the end of the path
        p=${p%/*}
    done
}

# for development only (to run without sourcing):
if [[ "$1" == "run" ]]
then
    __brujula_prompt
fi
