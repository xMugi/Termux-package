#!/data/data/com.termux/files/usr/bin/bash

export REPO_URL=https://github.com/xMugi/Termux-package.git

termux-setup-storage

pkg update && pkg upgrade -y && pkg install -y tur-repo neofetch python php termux-services termux-tools tmux android-tools nodejs git perl bash nano ruby build-essential ffmpeg curl openssl openssh wget clang nmap w3m coreutils fish zip figlet cowsay unzip wcalc bmon unrar golang termux-api dnsutils rclone


git clone "${REPO_URL}"
cd Termux-package
mkdir ~/.termux/boot
cp sshd ~/.termux/boot && chmod +x ~/.termux/boot/sshd
cp adb ~/.termux/boot && chmod +x ~/.termux/boot/adb
