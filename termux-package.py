#!/usr/bin/python3
import os
import time
import sys

os.system("clear")
print(''' \033[93m
install all packages ok''')
print('''\033[96m
This Command for access Storage in Termux
[00] termux-setup-storage''')

os.system("""
apt update && apt upgrade -y &&
apt install -y python python2 php python-dev python3 termux-service android-tools java git perl bash nano curl openssl openssh wget clang nmap w3m hydra ruby macchanger host dnsutils coreutils fish zip figlet cowsay unzip wcalc bmon unrar proot golang
""")

print ("Allow the Button For Access the Storage in Termux")


os.system ("termux-setup-storage")


input("\n\nPress the enter key to exit : ")
