#!/data/data/com.termux/files/usr/bin/bash

export REPO_URL=https://github.com/xMugi/Termux-package.git
export BRANCH=main

pkg update -y
pkg install -y git python

git clone "${REPO_URL}"
cd Termux-package

python termux-package.py
