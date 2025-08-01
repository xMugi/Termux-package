#!/data/data/com.termux/files/usr/bin/bash

export REPO_URL=https://github.com/xMugi/Termux-package.git
export BRANCH=main

termux-setup-storage

pkg update && pkg upgrade -y && pkg install -y python php termux-services termux-tools tmux android-tools nodejs git perl bash nano ruby build-essential ffmpeg curl openssl openssh wget clang nmap w3m coreutils fish zip figlet cowsay unzip wcalc bmon unrar proot golang termux-wifi-connectioninfo dnsutils


git clone "${REPO_URL}"
cd Termux-package
