# Frost
# Tom Shawver
# MIT License
# Based on Pure by Sindre Sorhus

# For my own and others sanity
# git:
# %b => current branch
# %a => current action (rebase/merge)
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current lines

prompt_frost_nocolor="%{$terminfo[sgr0]%}"
prompt_frost_colors=(
    "${prompt_frost_nocolor}%F{blue}"
    "${prompt_frost_nocolor}%F{blue}%{$terminfo[bold]%}"
    "${prompt_frost_nocolor}%F{green}"
    "${prompt_frost_nocolor}%F{green}%{$terminfo[bold]%}"
    "${prompt_frost_nocolor}%F{red}"
    "${prompt_frost_nocolor}%F{red}%{$terminfo[bold]%}"
    "${prompt_frost_nocolor}%F{yellow}"
    "${prompt_frost_nocolor}%F{yellow}%{$terminfo[bold]%}"
)
prompt_frost_inschar=${FROST_PCHAR_INSERT:-➤}
prompt_frost_normchar=${FROST_PCHAR_NORMAL:-⊙}
prompt_frost_pchar=${prompt_frost_inschar}
prompt_frost_gitcleanchar=${FROST_GIT_CLEAN_CHAR:-✔}
prompt_frost_gitdirtychar=${FROST_GIT_DIRTY_CHAR:-✱}
prompt_frost_retcodechar=${FROST_RETCODE_CHAR:-↵}

# turns seconds into human readable time
# 165392 => 1d 21h 56m 32s
# https://github.com/sindresorhus/pretty-time-zsh
prompt_frost_human_time_to_var() {
    local human="" total_seconds=$1 var=$2
    local days=$(( total_seconds / 60 / 60 / 24 ))
    local hours=$(( total_seconds / 60 / 60 % 24 ))
    local minutes=$(( total_seconds / 60 % 60 ))
    local seconds=$(( total_seconds % 60 ))
    (( days > 0 )) && human+="${days}d "
    (( hours > 0 )) && human+="${hours}h "
    (( minutes > 0 )) && human+="${minutes}m "
    human+="${seconds}s"

    # store human readable time in variable as specified by caller
    typeset -g "${var}"="${human}"
}

# stores (into prompt_frost_cmd_exec_time) the exec time of the last command if set threshold was exceeded
prompt_frost_check_cmd_exec_time() {
    integer elapsed
    (( elapsed = EPOCHSECONDS - ${prompt_frost_cmd_timestamp:-$EPOCHSECONDS} ))
    prompt_frost_cmd_exec_time=
    (( elapsed > ${FROST_CMD_MAX_EXEC_TIME:=5} )) && {
        prompt_frost_human_time_to_var $elapsed "prompt_frost_cmd_exec_time"
    }
}

prompt_frost_clear_screen() {
    # enable output to terminal
    zle -I
    # clear screen and move cursor to (0, 0)
    print -n '\e[2J\e[0;0H'
    # print preprompt
    prompt_frost_preprompt_render precmd
}

prompt_frost_set_title() {
    # emacs terminal does not support settings the title
    (( ${+EMACS} )) && return

    # tell the terminal we are setting the title
    print -n '\e]0;'
    # show hostname if connected through ssh
    [[ -n $SSH_CONNECTION ]] && print -Pn '(%m) '
    case $1 in
        expand-prompt)
            print -Pn $2;;
        ignore-escape)
            print -rn $2;;
    esac
    # end set title
    print -n '\a'
}

prompt_frost_preexec() {
    # attempt to detect and prevent prompt_frost_async_git_fetch from interfering with user initiated git or hub fetch
    [[ $2 =~ (git|hub)\ .*(pull|fetch) ]] && async_flush_jobs 'prompt_frost'

    prompt_frost_cmd_timestamp=$EPOCHSECONDS

    # shows the current dir and executed command in the title while a process is active
    prompt_frost_set_title 'ignore-escape' "$PWD:t: $2"
}

# string length ignoring ansi escapes
prompt_frost_string_length_to_var() {
    local str=$1 var=$2 length
    # perform expansion on str and check length
    length=$(( ${#${(S%%)str//(\%([KF1]|)\{*\}|\%[Bbkf])}} ))

    # store string length in variable as specified by caller
    typeset -g "${var}"="${length}"
}

prompt_frost_preprompt_render() {
    # store the current prompt_subst setting so that it can be restored later
    local prompt_subst_status=$options[prompt_subst]

    # make sure prompt_subst is unset to prevent parameter expansion in preprompt
    setopt local_options no_prompt_subst

    # check that no command is currently running, the preprompt will otherwise be rendered in the wrong place
    [[ -n ${prompt_frost_cmd_timestamp+x} && "$1" != "precmd" ]] && return

    # set color for git branch/dirty status, change color if dirty checking has been delayed
    local git_color=${prompt_frost_colors[2]}
    [[ -n ${prompt_frost_git_last_dirty_check_timestamp+x} ]] && git_color=${prompt_frost_colors[6]}

    # Remote hosts change colors
    if [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then
        local host="${prompt_frost_colors[8]}%m" # SSH
    else
        local host="${prompt_frost_colors[4]}%m" # no SSH
    fi

    # Root user changes color
    local user="%(!.${prompt_frost_colors[6]}.${prompt_frost_colors[4]})%n"

    # construct preprompt, beginning with user@host
    local preprompt="${prompt_frost_colors[1]}╭─<${user}${prompt_frost_colors[1]}@${host}${prompt_frost_colors[1]}>─"
    # path
    preprompt+="<${prompt_frost_colors[2]}%~${prompt_frost_colors[1]}>─"
    # git info
    if [ -n "$vcs_info_msg_0_" ]; then
        preprompt+="<${git_color}${vcs_info_msg_0_}${prompt_frost_colors[1]}∙"
        preprompt+="${prompt_frost_git_dirty}%f"
        preprompt+="${prompt_frost_colors[8]}${prompt_frost_git_arrows}%f${prompt_frost_colors[1]}>─"
    fi
    # execution time
    if [[ "${FROST_SHOW_EXEC_TIME:-1}" -eq 1 && -n "${prompt_frost_cmd_exec_time}" ]]; then
        preprompt+="<${prompt_frost_colors[7]}${prompt_frost_cmd_exec_time}%f${prompt_frost_colors[1]}>─"
    fi
    # local time
    if [ "${FROST_SHOW_CLOCK:-1}" -eq 1 ]; then
        preprompt+="<${prompt_frost_colors[2]}%D{%L:%M%p}${prompt_frost_colors[1]}>─"
    fi
    # pretty pretty end cap
    preprompt+="◇"

    # make sure prompt_frost_last_preprompt is a global array
    typeset -g -a prompt_frost_last_preprompt

    # if executing through precmd, do not perform fancy terminal editing
    if [[ "$1" == "precmd" ]]; then
        print -P "\n${preprompt}"
    else
        # only redraw if the expanded preprompt has changed
        [[ "${prompt_frost_last_preprompt[2]}" != "${(S%%)preprompt}" ]] || return

        # calculate length of preprompt and store it locally in preprompt_length
        integer preprompt_length lines
        prompt_frost_string_length_to_var "${preprompt}" "preprompt_length"

        # calculate number of preprompt lines for redraw purposes
        (( lines = ( preprompt_length - 1 ) / COLUMNS + 1 ))

        # calculate previous preprompt lines to figure out how the new preprompt should behave
        integer last_preprompt_length last_lines
        prompt_frost_string_length_to_var "${prompt_frost_last_preprompt[1]}" "last_preprompt_length"
        (( last_lines = ( last_preprompt_length - 1 ) / COLUMNS + 1 ))

        # clr_prev_preprompt erases visual artifacts from previous preprompt
        local clr_prev_preprompt
        if (( last_lines > lines )); then
            # move cursor up by last_lines, clear the line and move it down by one line
            clr_prev_preprompt="\e[${last_lines}A\e[2K\e[1B"
            while (( last_lines - lines > 1 )); do
                # clear the line and move cursor down by one
                clr_prev_preprompt+='\e[2K\e[1B'
                (( last_lines-- ))
            done

            # move cursor into correct position for preprompt update
            clr_prev_preprompt+="\e[${lines}B"
        # create more space for preprompt if new preprompt has more lines than last
        elif (( last_lines < lines )); then
            # move cursor using newlines because ansi cursor movement can't push the cursor beyond the last line
            printf $'\n'%.0s {1..$(( lines - last_lines ))}
        fi

        # disable clearing of line if last char of preprompt is last column of terminal
        local clr='\e[K'
        (( COLUMNS * lines == preprompt_length )) && clr=

        # modify previous preprompt
        print -Pn "${clr_prev_preprompt}\e[${lines}A\e[${COLUMNS}D${preprompt}${clr}\n"

        if [[ $prompt_subst_status = 'on' ]]; then
            # re-eanble prompt_subst for expansion on PS1
            setopt prompt_subst
        fi

        # redraw prompt (also resets cursor position)
        zle && zle .reset-prompt
    fi

    # store both unexpanded and expanded preprompt for comparison
    prompt_frost_last_preprompt=("$preprompt" "${(S%%)preprompt}")
}

prompt_frost_precmd() {
    # check exec time and store it in a variable
    prompt_frost_check_cmd_exec_time

    # by making sure that prompt_frost_cmd_timestamp is defined here the async functions are prevented from interfering
    # with the initial preprompt rendering
    prompt_frost_cmd_timestamp=

    # shows the full path in the title
    prompt_frost_set_title 'expand-prompt' '%~'

    # get vcs info
    vcs_info

    # preform async git dirty check and fetch
    prompt_frost_async_tasks

    # print the preprompt
    prompt_frost_preprompt_render "precmd"

    # remove the prompt_frost_cmd_timestamp, indicating that precmd has completed
    unset prompt_frost_cmd_timestamp
}

# fastest possible way to check if repo is dirty
prompt_frost_async_git_dirty() {
    setopt localoptions noshwordsplit
    local untracked_dirty=$1 dir=$2

    # use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
    builtin cd -q $dir

    if [[ $untracked_dirty = 0 ]]; then
        command git diff --no-ext-diff --quiet --exit-code
    else
        test -z "$(command git status --porcelain --ignore-submodules -unormal)"
    fi

    return $?
}

prompt_frost_async_git_fetch() {
    setopt localoptions noshwordsplit
    # use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
    builtin cd -q $1

    # set GIT_TERMINAL_PROMPT=0 to disable auth prompting for git fetch (git 2.3+)
    export GIT_TERMINAL_PROMPT=0
    # set ssh BachMode to disable all interactive ssh password prompting
    export GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-"ssh -o BatchMode=yes"}

    command git -c gc.auto=0 fetch &>/dev/null || return 1

    # check arrow status after a successful git fetch
    prompt_frost_async_git_arrows $1
}

prompt_frost_async_git_arrows() {
    setopt localoptions noshwordsplit
    builtin cd -q $1
    command git rev-list --left-right --count HEAD...@'{u}'
}

prompt_frost_async_tasks() {
    setopt localoptions noshwordsplit

    # initialize async worker
    ((!${prompt_frost_async_init:-0})) && {
        async_start_worker "prompt_frost" -u -n
        async_register_callback "prompt_frost" prompt_frost_async_callback
        prompt_frost_async_init=1
    }

    # store working_tree without the "x" prefix
    local working_tree="${vcs_info_msg_1_#x}"

    # check if the working tree changed (prompt_frost_current_working_tree is prefixed by "x")
    if [[ ${prompt_frost_current_working_tree#x} != $working_tree ]]; then
        # stop any running async jobs
        async_flush_jobs "prompt_frost"

        # reset git preprompt variables, switching working tree
        unset prompt_frost_git_dirty
        unset prompt_frost_git_last_dirty_check_timestamp
        prompt_frost_git_arrows=

        # set the new working tree and prefix with "x" to prevent the creation of a named path by AUTO_NAME_DIRS
        prompt_frost_current_working_tree="x${working_tree}"
    fi

    # only perform tasks inside git working tree
    [[ -n $working_tree ]] || return

    async_job "prompt_frost" prompt_frost_async_git_arrows $working_tree

    # do not preform git fetch if it is disabled or working_tree == HOME
    if (( ${FROST_GIT_PULL:-1} )) && [[ $working_tree != $HOME ]]; then
        # tell worker to do a git fetch
        async_job "prompt_frost" prompt_frost_async_git_fetch $working_tree
    fi

    # if dirty checking is sufficiently fast, tell worker to check it again, or wait for timeout
    integer time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_frost_git_last_dirty_check_timestamp:-0} ))
    if (( time_since_last_dirty_check > ${FROST_GIT_DELAY_DIRTY_CHECK:-1800} )); then
        unset prompt_frost_git_last_dirty_check_timestamp
        # check check if there is anything to pull
        async_job "prompt_frost" prompt_frost_async_git_dirty ${FROST_GIT_UNTRACKED_DIRTY:-1} $working_tree
    fi
}

prompt_frost_check_git_arrows() {
    setopt localoptions noshwordsplit
    local arrows left=${1:-0} right=${2:-0}

    (( right > 0 )) && arrows+=${FROST_GIT_DOWN_ARROW:-⇣}
    (( left > 0 )) && arrows+=${FROST_GIT_UP_ARROW:-⇡}

    [[ -n $arrows ]] || return
    typeset -g REPLY="$arrows"
}

prompt_frost_async_callback() {
    setopt localoptions noshwordsplit
    local job=$1 code=$2 output=$3 exec_time=$4

    case $job in
        prompt_frost_async_git_dirty)
            local prev_dirty=$prompt_frost_git_dirty
            if (( code == 0 )); then
                prompt_frost_git_dirty="${prompt_frost_colors[3]}${prompt_frost_gitcleanchar}${prompt_frost_nocolor}"
            else
                prompt_frost_git_dirty="${prompt_frost_colors[6]}${prompt_frost_gitdirtychar}${prompt_frost_nocolor}"
            fi

            [[ $prev_dirty != $prompt_frost_git_dirty ]] && prompt_frost_preprompt_render

            # When prompt_frost_git_last_dirty_check_timestamp is set, the git info is displayed in a different color.
            # To distinguish between a "fresh" and a "cached" result, the preprompt is rendered before setting this
            # variable. Thus, only upon next rendering of the preprompt will the result appear in a different color.
            (( $exec_time > 2 )) && prompt_frost_git_last_dirty_check_timestamp=$EPOCHSECONDS
            ;;
        prompt_frost_async_git_fetch|prompt_frost_async_git_arrows)
            # prompt_frost_async_git_fetch executes prompt_frost_async_git_arrows
            # after a successful fetch.
            if (( code == 0 )); then
                local REPLY
                prompt_frost_check_git_arrows ${(ps:\t:)output}
                if [[ $prompt_frost_git_arrows != $REPLY ]]; then
                    prompt_frost_git_arrows=$REPLY
                    prompt_frost_preprompt_render
                fi
            fi
            ;;
    esac
}

prompt_frost_generate() {
    # prompt changes color if we're root
    local promptcolor='%(!.${prompt_frost_colors[6]}.${prompt_frost_nocolor})'
    PROMPT="${prompt_frost_colors[1]}╰─${promptcolor}${prompt_frost_pchar}${prompt_frost_nocolor} "

    # Set a right prompt with the non-zero exit code
    RPROMPT='%(?..${prompt_frost_colors[5]}%? ${prompt_frost_retcodechar}${prompt_frost_nocolor})'
}

prompt_frost_setup() {
    local autoload_name=$1; shift

    # prevent percentage showing up
    # if output doesn't end with a newline
    export PROMPT_EOL_MARK=''

    prompt_opts=(subst percent)

    # if autoload_name or eval context differ, frost wasn't autoloaded via
    # promptinit and we need to take care of setting the options ourselves
    if [[ $autoload_name != prompt_frost_setup ]] || [[ $zsh_eval_context[-2] != loadautofunc ]]; then
        # borrowed from `promptinit`, set the frost prompt options
        setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"
    fi

    zmodload zsh/datetime
    zmodload zsh/zle
    zmodload zsh/parameter

    autoload -Uz add-zsh-hook
    autoload -Uz vcs_info
    autoload -Uz async && async

    add-zsh-hook precmd prompt_frost_precmd
    add-zsh-hook preexec prompt_frost_preexec

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' use-simple true
    # only export two msg variables from vcs_info
    zstyle ':vcs_info:*' max-exports 2
    # vcs_info_msg_0_ = ' %b' (for branch)
    # vcs_info_msg_1_ = 'x%R' git top level (%R), x-prefix prevents creation of a named path (AUTO_NAME_DIRS)
    zstyle ':vcs_info:git*' formats '%b' 'x%R'
    zstyle ':vcs_info:git*' actionformats '%b|%a' 'x%R'

    # if the user has not registered a custom zle widget for clear-screen,
    # override the builtin one so that the preprompt is displayed correctly when
    # ^L is issued.
    if [[ $widgets[clear-screen] == 'builtin' ]]; then
        zle -N clear-screen prompt_frost_clear_screen
    fi

    prompt_frost_generate
}

# Update the current prompt with the current vi-mode status
zle-keymap-select() {
    prompt_frost_pchar="${${KEYMAP/vicmd/${prompt_frost_normchar}}/(main|viins)/${prompt_frost_inschar}}"
    prompt_frost_generate
    zle .reset-prompt
}

zle -N zle-keymap-select
prompt_frost_setup "$0" "$@"

