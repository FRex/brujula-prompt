#!/bin/bash

function __brujula_prompt() {
    p=$PWD
    x=24
    for (( i=0 ; i<$x ; i++ ))
    do
        if [[ -z "$p" ]]
        then
            echo -e "\u001b[33m$PWD\u001b[0m"
            break
        fi

        if [[ -f "$p/.git/HEAD" ]]
        then
            read line < "$p/.git/HEAD"
            trimmedline=${line#ref: refs/heads/}

            path2=${PWD#$p}
            path1=${PWD%$path2}

            if [[ -z "$path2" ]]
            then
                path2='/'
            fi

            fullpath="\u001b[33m$path1\u001b[0m\u001b[32m$path2\u001b[0m"
            if [[ "$trimmedline" != "$line" ]]
            then
                echo -e "$fullpath \u001b[36m($trimmedline)\u001b[0m"
            else
                echo -e "$fullpath \u001b[32m($trimmedline)\u001b[0m"
            fi
            break
        fi
        p=${p%/*}
    done
}
