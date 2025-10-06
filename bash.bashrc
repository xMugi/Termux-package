#forked from https://github.com/knightfall-cs/termux-bashrc
# Last modified: 2025/08/01

#### Global variables #################

# User name
#change your user name here
user_name=$USER

# Default editor
editor="nano"

#### Environment variables ############

# `grep default` highlight color
export GREP_COLOR="1;32"

# Colored man
export MANPAGER="less -R --use-color -Dd+g -Du+b"

# EDITOR
export EDITOR=$editor
export SUDO_EDITOR=$editor

# USER
#export USER=$user_name

# Path
export ETC="/data/data/com.termux/files/usr/etc"

#### History settings #################

# append to the history file, don't overwrite it
shopt -s histappend

# load results of history substitution into the readline editing buffer
shopt -s histverify

# don't put duplicate lines or lines starting with space in the history
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

#### Autocompletion ###################

# cycle through all matches with 'TAB' key
bind 'TAB:menu-complete'

# necessary for programmable completion
shopt -s extglob

# cd when entering just a path
shopt -s autocd

#### Prompt ###########################
sym="㉿"
bar_cr="34"    # Blue for the bars
sym_cr="31"    # Red for the symbol
name_cr="33"   # Yellow for the username
host_cr="36"   # Cyan for the IP address (hostname)
end_cr="32"    # Green for the prompt end
dir_cr="31"    # Magenta for the current directory

local_ip=$(termux-wifi-connectioninfo | grep "ip" | cut -d: -f2 | tr -d '", ') # Get the local IP address

PS1='\[\033[0;${bar_cr}m\]┌──(\[\033[1;${name_cr}m\]${user_name}\[\033[1;${sym_cr}m\]${sym}\[\033[1;${host_cr}m\]${local_ip}\[\033[0;${bar_cr}m\])-[\[\033[1;${dir_cr}m\]\w\[\033[0;${bar_cr}m\]]
\[\033[0;${bar_cr}m\]└─\[\033[1;${end_cr}m\]\$\[\033[0m\] '

#### Aliases ##########################

# enable color support of ls, grep and ip, also add handy aliases
if [[ -x /usr/bin/dircolors ]]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias diff='diff --color=auto'
fi

# common commands
alias ..='cd ..'
alias .2='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias lm='ls | more'
alias ll='ls -lFh'
alias la='ls -alFh --group-directories-first'
alias l1='ls -1F --group-directories-first'
alias l1m='ls -1F --group-directories-first | more'
alias lh='ls -ld .??*'
alias lsn='ls | cat -n'
alias mkdir='mkdir -p -v'
alias cp='cp --preserve=all'
alias cpv='cp --preserve=all -v'
alias cpr='cp --preserve=all -R'
alias cpp='rsync -ahW --info=progress2'
alias cs='printf "\033c"'
alias q='exit'
alias c='clear'
alias cls='clear && ls'
alias count='find . -type f | wc -l'
alias fbig="find . -size +128M -type f -printf '%s %p\n'| sort -nr | head -16"

# memory/CPU
alias free='free -mt'
alias psa='ps auxf'
alias cputemp='sensors | grep Core'

# applications shortcuts
alias ip='termux-wifi-connectioninfo'
alias myip='curl -s -m 5 https://ipleak.net/json/'
alias e=$editor
alias p='python3'
alias w3mduck='w3m https://duckduckgo.com'
alias edit-bashrc=$editor' /data/data/com.termux/files/usr/etc/bash.bashrc'
alias timenow='date +"%T"'
alias datenow='date +"%d-%m-%Y"'
alias untar='tar -zxvf '
alias wget='wget -c '
alias genpass='openssl rand -base64 12'
alias phttp='python -m http.server 8000'
alias kn='python /data/data/com.termux/files/home/keynote/keynote.py' # https://github.com/knightfall-cs/keynote
alias dnstest='while true; do dig +short google.com; sleep 2; done'

#### Functions ########################

# If user has entered command which invokes non-available
# utility, command-not-found will give a package suggestions.
if [ -x /data/data/com.termux/files/usr/libexec/termux/command-not-found ]; then
	command_not_found_handle() {
		/data/data/com.termux/files/usr/libexec/termux/command-not-found "$1"
	}
fi

# nnn "cd on quit"
n()
{
    # Block nesting of nnn in subshells
    if [ -n $NNNVL ] && [ "${NNNVL:-0}" -ge 1 ]; then
        echo "nnn is already running"
        return
    fi

    # The behaviour is set to cd on quit (nnn checks if NNN_TMPFILE is set)
    # If NNN_TMPFILE is set to a custom path, it must be exported for nnn to
    # see. To cd on quit only on ^G, remove the "export" and make sure not to
    # use a custom path, i.e. set NNN_TMPFILE *exactly* as follows:
    #   NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"

    # Unmask ^Q (, ^V etc.) (if required, see `stty -a`) to Quit nnn
    # stty start undef
    # stty stop undef
    # stty lwrap undef
    # stty lnext undef

    nnn "$@"

    if [ -f "$NNN_TMPFILE" ]; then
        . "$NNN_TMPFILE"
        rm -f "$NNN_TMPFILE" > /dev/null
    fi
}

green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
reset='\e[0m' 
color_T='\e[1;31m' # Red
color_E='\e[1;32m' # Green
color_R='\e[1;33m' # Yellow
color_M='\e[1;34m' # Blue
color_U='\e[1;35m' # Magenta
color_X='\e[1;36m' # Cyan
reset='\e[0m'

#### Display ########################

echo -e "\e[0;37m"
clear
echo
# Define the ASCII art for each letter, line by line
# The art below is from the provided icon.txt file
t_art=(
'████████╗'
'╚══██╔══╝'
'   ██║   '
'   ██║   '
'   ██║   '
'   ╚═╝   '
)
e_art=(
'███████╗'
'██╔════╝'
'█████╗  '
'██╔══╝  '
'███████╗'
'╚══════╝'
)
r_art=(
'██████╗ '
'██╔══██╗'
'██████╔╝'
'██╔══██╗'
'██║  ██║'
'╚═╝  ╚═╝'
)
m_art=(
'███╗   ███╗'
'████╗ ████║'
'██╔████╔██║'
'██║╚██╔╝██║'
'██║ ╚═╝ ██║'
'╚═╝     ╚═╝'
)
u_art=(
'██╗   ██╗'
'██║   ██║'
'██║   ██║'
'██║   ██║'
'╚██████╔╝'
' ╚═════╝ '
)
x_art=(
'██╗  ██╗'
'╚██╗██╔╝'
' ╚███╔╝ '
' ██╔██╗ '
'██╔╝ ██╗'
'╚═╝  ╚═╝'
)
# Loop through the 6 lines of the art and print each letter with its color
for i in "${!t_art[@]}"; do
    echo -e -n "${color_T}${t_art[i]}${color_E}${e_art[i]}${color_R}${r_art[i]}${color_M}${m_art[i]}${color_U}${u_art[i]}${color_X}${x_art[i]}${reset}"
    echo
done
echo
echo -e "${yellow}Docs:${reset}    ${cyan}https://termux.dev/docs${reset}"
echo
echo -e "${green}Search:${reset}  pkg search <query>"
echo -e "${blue}Install:${reset} pkg install <package>"
echo -e "${cyan}Upgrade:${reset} pkg upgrade"
echo
echo
echo
