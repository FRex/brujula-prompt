#!/bin/bash

function __brujula_prompt() {
    local p="$PWD"

    # amount of iterations, could come from an env var later
    local x=24

    # c like for loop allows $x, {1..24} syntax wouldn't
    for (( i=0 ; i<x ; i++ ))
    do
        # print yellow path if we reached the root
        if [[ -z "$p" ]]
        then
            echo -e "\u001b[33m$PWD\u001b[0m"
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

            # print them in different colors
            local fullpath="\u001b[33m$path1\u001b[0m\u001b[32m$path2\u001b[0m"

            local hiddenfiles=(.*)

            # if we stripped ref prefix its a branch HEAD, else its commit
            if [[ "$trimmedline" != "$line" ]]
            then
                echo -e "$fullpath ${#hiddenfiles[@]}. \u001b[36m($trimmedline)\u001b[0m"
            else
                echo -e "$fullpath ${#hiddenfiles[@]}. \u001b[32m($trimmedline)\u001b[0m"
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
