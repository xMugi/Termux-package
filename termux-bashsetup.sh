#!/data/data/com.termux/files/usr/bin/bash

mv -v /data/data/com.termux/files/usr/etc/bash.bashrc /data/data/com.termux/files/usr/etc/bash.bashrc.backup

cd Termux-package/ && cp bash.bashrc /data/data/com.termux/files/usr/etc && exit
