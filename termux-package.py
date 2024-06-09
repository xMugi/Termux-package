#!/usr/bin/python3
import os
import time
import sys

os.system("clear")
print(''' \033[93m
install all packages ok''')

os.system("""
pkg update && pkg upgrade -y && pkg install -y python php python-dev termux-services termux-tools tmux android-tools nodejs git perl bash nano ruby build-essential ffmpeg curl openssl openssh wget clang nmap w3m coreutils fish zip figlet cowsay unzip wcalc bmon unrar proot golang
""")

print('''\033[96m
Allow the Button For Access the Storage in Termux''')

os.system ("termux-setup-storage")


input("\033[96m\n\nPress the enter key to exit : ")
