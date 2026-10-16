#!/data/data/com.termux/files/usr/bin/sh
# Wireless ADB on 7777 (RustDesk elevation), Termux:Boot FALLBACK.
# PRIMARY is the root service.d script — this only fires where that is absent.
# WHY "command -v su": without root this whole block is a no-op setprop fail.
command -v su >/dev/null 2>&1 || exit 0
termux-wake-lock
su -c 'setprop service.adb.tcp.port 7777; stop adbd; start adbd'
