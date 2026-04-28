#!/data/data/com.termux/files/usr/bin/bash
rm ~/.bashrc
mv -v /data/data/com.termux/files/usr/etc/bash.bashrc /data/data/com.termux/files/usr/etc/bash.bashrc.backup
cp bash.bashrc /data/data/com.termux/files/usr/etc
ln -sf /data/data/com.termux/files/usr/etc/bash.bashrc ~/.bashrc
mkdir -p ~/.config/neofetch && cp neofetch.conf ~/.config/neofetch/config.conf
exit
