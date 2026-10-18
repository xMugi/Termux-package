#!/data/data/com.termux/files/usr/bin/bash
# Autostart wiring — three layers, all idempotent.
#
#   L1  /data/adb/service.d/00-termux-boot.sh    (PRIMARY, root boot script for
#                                                Magisk AND KernelSU service.d)
#       → adb tcp 7777 for RustDesk, phantom-killer/freezer off (Android 12-16 keys),
#         doze whitelist, Termux wake-lock + sshd via RunCommandService — as ROOT at boot.
#   L2  ~/.termux/boot/{sshd,adb}                (FALLBACK via Termux:Boot app;
#         root steps are skipped silently when su is unavailable)
#   L3  $HOME/.termux/termux.properties          allow-external-apps = true
#         REQUIRED by L1: termux blocks external RunCommand intents otherwise.

set -e
cd "$(dirname "$0")"

# --- L3: allow-external-apps ---------------------------------------------------
# WHY "^allow-...": the stock template ships an COMMENTED "# allow-external-apps =
# true" line which a plain grep would otherwise match falsely (as happened live).
mkdir -p "$HOME/.termux"
touch "$HOME/.termux/termux.properties"
grep -q "^allow-external-apps" "$HOME/.termux/termux.properties" || \
    echo "allow-external-apps = true" >> "$HOME/.termux/termux.properties"
echo "termux.properties: allow-external-apps active"

# --- L2: Termux:Boot fallback scripts ------------------------------------------
# WHY sshd in fallback: phones without root (or deleted service.d entries).
# sshd on an already listening port exits harmless (RC-bind) -> idempotent.
mkdir -p "$HOME/.termux/boot"
install -m 700 ./sshd "$HOME/.termux/boot/sshd"
install -m 700 ./adb  "$HOME/.termux/boot/adb"
echo "Termux:Boot fallback scripts in ~/.termux/boot/"
echo "  NOTE: Termux:Boot app must be opened once so BOOT_COMPLETED is received."

# --- L1: root service.d script ---------------------------------------------------
# WHY stdin-pipe: `su -c "cat > file" < local` runs entirely in the phone's root
# context; no scp needed — works standalone from the clone inside Termux.
if su -c "true" >/dev/null 2>&1; then
    su -c "mkdir -p /data/adb/service.d"
    if su -c "cat > /data/adb/service.d/00-termux-boot.sh" < ./root-boot/00-termux-boot.sh; then
        su -c "chmod 700 /data/adb/service.d/00-termux-boot.sh"
        echo "root: service.d boot script installed (reboot needed, ONCE — cached_apps_freezer)"
    else
        echo "root: ERROR while writing service.d script" >&2
        exit 1
    fi
else
    echo "root: no su available — L1 skipped, L2 fallback stays in place"
fi
