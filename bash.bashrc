#forked from https://github.com/xMugi/Termux-package
# Last modified: 2026/3/31

#### Global variables #################

# User name
#change your user name here
username=$USER

# Default editor
editor="nano"

## System Data Gathering

# Get the local IP address
LOCAL_IP=$(sudo ifconfig wlan0 | grep 'inet ' | awk '{print $2}')

# Get the remote IP address
ext_ip=$(curl -s -m 5 https://ipleak.net/json/ | grep '"ip"' | cut -d: -f2 | tr -d '", ')

TEMP=$(sudo cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | cut -c1-2)
UPTIME=$(uptime -p | sed 's/up //')
STORAGE=$(df -h /data | awk 'NR==2 {print $4}')

#Color
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[1;34m'
BLUE='\033[38;5;21m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

#### Environment variables ############

# `grep default` highlight color
export GREP_COLOR="1;32"

# Colored man
export MANPAGER="less -R --use-color -Dd+g -Du+b"

# EDITOR
export EDITOR=$editor
export SUDO_EDITOR=$editor
export VISUAL="vim"

# Path
export PATH=$PATH:$HOME/bin
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

PS1="\[${PURPLE}\]┌──(\[${YELLOW}\]${username}\[${RED}\]${sym}\[${CYAN}\]${LOCAL_IP}\[${PURPLE}\])-[\[${MAGENTA}\]\\w\[${PURPLE}\]]
\[${PURPLE}\]└─\[${GREEN}\]\\$\[${NC}\] "

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
alias ll='ls -lFh'
alias la='ls -alFh --group-directories-first'
alias l1='ls -1F --group-directories-first'
alias lh='ls -ld .??*'
alias mkdir='mkdir -p -v'
alias cp='cp --preserve=all'
alias cpv='cp --preserve=all -v'
alias cpr='cp --preserve=all -R'
alias cpp='rsync -ahW --info=progress2'
alias q='exit'
alias count='find . -type f | wc -l'
alias fbig="find . -size +128M -type f -printf '%s %p\n'| sort -nr | head -16"

# memory/CPU
alias ram='free -mt'
alias psa='ps auxf'

# applications shortcuts
alias c='clear'
alias e=$editor
alias p='python3'
alias edit-bashrc=$editor' /data/data/com.termux/files/usr/etc/bash.bashrc'
alias timenow='date +"%T"'
alias datenow='date +"%d-%m-%Y"'
alias untar='tar -zxvf '
alias wget='wget -c '
alias phttp='python -m http.server 8000'
alias dnstest='while true; do dig +short google.com; sleep 2; done'

#### Functions ########################
#External IP
myip() {
    echo -e "${PURPLE}Local  IP${WHITE}: ${GREEN}$LOCAL_IP${NC}"
    echo -e "${CYAN}Remote IP${WHITE}: ${RED}$ext_ip${NC}"
}

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
    echo -e -n "${RED}${t_art[i]}${GREEN}${e_art[i]}${YELLOW}${r_art[i]}${BLUE}${m_art[i]}${MAGENTA}${u_art[i]}${CYAN}${x_art[i]}${NC}"
    echo
done

echo -e "${MAGENTA}=====================================================${NC}"
echo -e "  ${PURPLE}IP      ${WHITE}:${RED}   $LOCAL_IP ${MAGENTA}~ ${GREEN}$ext_ip${NC}"
echo -e "  ${PURPLE}CPU TEMP${WHITE}:   ${YELLOW}${TEMP}°C${NC}"
echo -e "  ${PURPLE}UPTIME  ${WHITE}:   $UPTIME"
echo -e "  ${PURPLE}STORAGE ${WHITE}:   ${GREEN}$STORAGE${NC} remaining"
echo -e "${MAGENTA}=====================================================${NC}"
echo -e "  ${PURPLE}Docs   ${WHITE} :${CYAN}   https://termux.dev/docs${NC}"
echo -e "  ${PURPLE}Search ${WHITE} :   pkg search ${RED}<query>${NC}"
echo -e "  ${PURPLE}Install${WHITE} :   pkg install ${RED}<package>${NC}"
echo
echo
