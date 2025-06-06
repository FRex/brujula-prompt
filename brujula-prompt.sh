#!/bin/bash
# NOTE: this script is meant to be safe to source, pretty much no matter what

# TODO: merge into the main function and put return code and time in it too
function __brujula_priv_print_deleted_pwd() {
    # amount of iterations, could come from an env var later
    # delete dir is a bad case so set a very high limit here
    local x=240
    local p="$PWD"
    local thisdir=''
    local backwardspath='.'
    local baddirs=''

    # c like for loop allows $x, {1..24} syntax wouldn't
    for ((i = 0; i < x; i++)); do
        # if the dir exists and is same then quit the loop
        if [[ "$p" -ef "$backwardspath" ]]; then
            break
        fi

        # cut off one /dir off the end of the path and go up one dir with ..
        thisdir=${p##*/}
        p=${p%/*}
        backwardspath="$backwardspath/.."

        # color dirs that exist (but are different) as magenta, deleted as red
        if [[ -d "$p/$thisdir" ]]; then
            baddirs="\u001b[35m/$thisdir\u001b[0m$baddirs"
        else
            baddirs="\u001b[31m/$thisdir\u001b[0m$baddirs"
        fi

        # strange case, can happen with git bash and deleted ramdisk on windows
        if [ -z "$p" ]; then
            # echo -e "$1 \u001b[31m$PWD\u001b[0m"
            break
        fi
    done

    echo -e "$1 \u001b[33m$p\u001b[0m$baddirs"
}

function __brujula_prompt() {
    local laststatus="$?"
    local before now elapsed uptimeseconds

    now="${EPOCHREALTIME/[.,]/}"
    before="$BRUJULA_EPOCHREALTIME"

    # figure out username based on the two variables
    local username="${USER:-$USERNAME}"

    # format time nicely into seconds.milliseconds
    # add at least two zeroes, so even 1 millisecond becomes at least 001
    elapsed="00$(((now - before) / 1000))"

    # split and join with a dot 3 digits from the end
    elapsed="${elapsed::-3}.${elapsed: -3}"

    # remove extra zeroes from the front, in case they were in seconds part
    [[ ${elapsed::1} == 0 ]] && elapsed="${elapsed##0}"
    [[ ${elapsed::1} == 0 ]] && elapsed="${elapsed##0}"

    # ensure at least one zero is present, so 123 ms = 0.123 seconds
    [[ ${elapsed::1} == . ]] && elapsed="0$elapsed"

    # add the unit s for seconds
    elapsed="${elapsed}s"

    if [ $laststatus -eq 0 ]; then
        local lastcommandstatus="\u001b[32m$laststatus\u001b[0m $elapsed"
    else
        local lastcommandstatus="\u001b[31m$laststatus\u001b[0m $elapsed"
    fi

    if [[ -z "$BRUJULA_NO_FILE_COUNT" ]]; then
        local hiddenfiles=(.*)
        local hiddenfilescount="${#hiddenfiles[@]}"
    else
        local hiddenfilescount='OFF'
    fi

    local userathost="\u001b[32m$username\u001b[33m@\u001b[32m$HOSTNAME\u001b[0m"
    # each dir has itself . and parent dir .. so less than 2 hidden files = deleted dir
    if [[ "$hiddenfilescount" -lt 2 ]]; then
        # in case of globskipdots being on, we can end up here with
        # hiddenfiles equal to .* so check . dir explicitly
        # to check if its on/off in bash: shopt | grep globskipdots
        # the -d works on git bash on Windows, e.g. if the drive gets formatted
        # the -ef works on Linux and catches both $PWD no longer existing and
        # being recreated, because . is kept alive so -d reports it exists, but
        # -ef reports them as unequal due to having different inode numbers
        if [[ ! -d . ]] || [[ ! . -ef "$PWD" ]]; then
            __brujula_priv_print_deleted_pwd "$userathost"
            return
        fi

        # if hiddenfiles array is just .* because glob failed then say 0 hidden files
        if [[ "${hiddenfiles[0]}" == ".*" ]] && [[ ! -f "${hiddenfiles[0]}" ]]; then
            hiddenfilescount=0
        fi
    fi

    if [[ -z "$BRUJULA_NO_FILE_COUNT" ]]; then
        local normalfiles=(*)
        local normalfilescount="${#normalfiles[@]}"
    else
        local normalfilescount='OFF'
        local hiddenfilescount='OFF' # setting again since in the if above we set it to 0
    fi
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
    local x=48

    # grab the first value from that file, and remove anything post first space
    # then anything post first dot (that file contains two floating numbers)
    read -r uptimeseconds </proc/uptime
    uptimeseconds=${uptimeseconds%% *}
    uptimeseconds=${uptimeseconds%%.*}

    local minutes="$((uptimeseconds / 60))"
    local hours="$((minutes / 60))"
    local minutes="$((minutes % 60))"
    # ensure minutes is a 2 digit string, even if its from 0 to 9
    [[ "${#minutes}" -eq 1 ]] && minutes="0$minutes"

    local endpart="UP=$hours:$minutes CMD=$BRUJULA_COMMAND_COUNT $lastcommandstatus"

    # c like for loop allows $x, {1..24} syntax wouldn't
    local i
    for ((i = 0; i < x; i++)); do
        # print yellow path if we reached the root
        if [[ -z "$p" ]]; then
            local path1="$PWD"
            [[ $path1 == $HOME* ]] && path1="${path1//"$HOME"/'~'}"
            echo -e "$userathost \u001b[33m$path1\u001b[0m $normalfilescount.$hiddenfilescount $endpart"
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
            [[ -z "$path2" ]] && path2='/'

            [[ $path1 == $HOME* ]] && path1="${path1//"$HOME"/'~'}"

            # print them in different colors
            local fullpath="\u001b[33m$path1\u001b[0m\u001b[32m$path2\u001b[0m"

            local changemark=''
            if [[ -n "$BRUJULA_USE_GIT_STATUS" ]]; then
                local gotany=0 gotdel=0 gotren=0 gotmod=0 gotadd=0 gotnew=0
                while read -r line; do
                    local c="${line::1}"
                    gotany=1
                    [[ "$c" == "D" ]] && gotdel=1
                    [[ "$c" == "R" ]] && gotren=1
                    [[ "$c" == "M" ]] && gotmod=1
                    [[ "$c" == "A" ]] && gotadd=1
                    [[ "$c" == "?" ]] && gotnew=1
                done < <(git status --porcelain=v1 2>/dev/null)

                [[ "$gotdel" -eq 1 ]] && changemark="${changemark}D"
                [[ "$gotren" -eq 1 ]] && changemark="${changemark}R"
                [[ "$gotmod" -eq 1 ]] && changemark="${changemark}M"
                [[ "$gotadd" -eq 1 ]] && changemark="${changemark}A"
                [[ "$gotnew" -eq 1 ]] && changemark="${changemark}?"
                [[ "$gotany" -eq 1 && -z "$changemark" ]] && changemark='*'
            fi

            # if we stripped ref prefix its a branch HEAD, else its commit
            if [[ "$trimmedline" != "$line" ]]; then
                echo -e "$userathost $fullpath $normalfilescount.$hiddenfilescount \u001b[36m($trimmedline\u001b[31m$changemark\u001b[36m)\u001b[0m $endpart"
            else
                echo -e "$userathost $fullpath $normalfilescount.$hiddenfilescount \u001b[32m($trimmedline\u001b[31m$changemark\u001b[32m)\u001b[0m $endpart"
            fi
            break
        fi

        # cut off one /dir off the end of the path
        p=${p%/*}
    done
}

# for development only (to benchmark):
if [[ "$1" == "run" ]]; then
    # TODO: assign other variables i need here, even though by default
    # they get treated as 0 when i later $(( + 1)) then
    BRUJULA_EPOCHREALTIME=${EPOCHREALTIME/[.,]/}
    BRUJULA_COMMAND_COUNT=0

    function __brujula_priv_run() {
        local before now total reps smallest elapsed i
        echo
        total=0
        smallest=999123123
        reps="${2:-125}"
        for ((i = 0; i < reps; i++)); do
            before=${EPOCHREALTIME/[.,]/}
            __brujula_prompt
            now=${EPOCHREALTIME/[.,]/}
            elapsed=$((now - before))
            total=$((total + elapsed))
            echo "$elapsed microseconds"$'\n'
            if [[ $elapsed -lt "$smallest" ]]; then
                smallest=$elapsed
            fi
        done
        echo "$smallest min and $((total / reps)) average microseconds over $reps runs"
    }

    __brujula_priv_run "$@"
fi

function __brujula_set_title() {
    # set the title via the escape sequence, just path, for now
    local fullpath="$PWD"
    [[ $fullpath == $HOME* ]] && fullpath="${fullpath//"$HOME"/'~'}"
    echo -en "\033]0;$fullpath\a"
    # only print newline here when these two mismatch, to avoid printing newline in
    # a new window/terminal/tab, and after clear (we alias clear to aid this)
    [[ "$BRUJULA_RENDER_COUNTER" -ne "$BRUJULA_RENDER_COUNTER_LAST_CLEAR" ]] && echo
}

if [[ "$1" == "install" ]]; then
    # for the timing of each command, set as soon as possible so time displayed in first prompt is
    # time between installing prompt and first display, so time of all other init stuff in bashrc
    BRUJULA_EPOCHREALTIME=${EPOCHREALTIME/[.,]/}

    # to always make sure the title is up to date
    PROMPT_COMMAND='__brujula_set_title'

    # take a substring starting at 0, of 0 chars, and use the $(()) to assign variable
    # since assigning variables in functions inside PS0 and PS1 does not work
    # shellcheck disable=SC2016 # this is expanded elsewhere so single quotes here are okay
    BRUJULA_TIME_UPDATER='${BRUJULA_TIME_UPDATER:0:$((BRUJULA_EPOCHREALTIME=${EPOCHREALTIME/[.,]/},0))}'

    # shellcheck disable=SC2034 # i use this in BRUJULA_RENDER_COUNTER_TRIGGER
    BRUJULA_RENDER_COUNTER=0

    # shellcheck disable=SC2034 # i use this in __brujula_set_title
    BRUJULA_RENDER_COUNTER_LAST_CLEAR=0

    # shellcheck disable=SC2016 # this is expanded elsewhere so single quotes here are okay
    BRUJULA_RENDER_COUNTER_TRIGGER='${BRUJULA_TIME_UPDATER:0:$((BRUJULA_RENDER_COUNTER=$((BRUJULA_RENDER_COUNTER+1)),0))}'

    # shellcheck disable=SC2034 # i use this variable in the PS0, to count total commands, excluding empty lines
    BRUJULA_COMMAND_COUNT=0

    # shellcheck disable=SC2016 # shellcheck doesn't see PS0 as special like PS1, PS2, etc.
    PS0="${BRUJULA_RENDER_COUNTER_TRIGGER}${BRUJULA_TIME_UPDATER}"'${BRUJULA_COMMAND_COUNT:0:$((BRUJULA_COMMAND_COUNT=$((BRUJULA_COMMAND_COUNT + 1)),0))}'

    # a nice 2 line prompt, writing area is always full with, and it also
    # prevents broken offset prompt if last command had no final newline
    PS1='`__brujula_prompt`\n$ '"${BRUJULA_TIME_UPDATER}${BRUJULA_RENDER_COUNTER_TRIGGER}"
    alias clear='BRUJULA_RENDER_COUNTER_LAST_CLEAR=$BRUJULA_RENDER_COUNTER;clear'
fi

if [[ "$1" != "install" && "$1" != "run" ]]; then
    echo "To run a benchmark:"
    echo "$BASH $0 run 10 # last argument is reps (optional)"
    echo
    echo "To install the prompt source the script:"
    echo ". $0 install"
    echo "To enable git status usage also set BRUJULA_USE_GIT_STATUS=1 in your bash."
    echo "To disable file counts (to improve performance for very large directories) you can set BRUJULA_NO_FILE_COUNT=1 in your bash."
fi
