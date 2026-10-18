#!/data/data/com.termux/files/usr/bin/bash
# Autostart wiring — three layers, all idempotent.
#
#   L1  /data/adb/service.d/00-termux-boot.sh    (PRIMARY, root boot script for
#                                                Magisk AND KernelSU service.d)
#       → adb tcp 7777 for RustDesk, phantom-killer/freezer off (Android 12-16 keys),
#         doze whitelist, Termux wake-lock + sshd via RunCommandService — as ROOT at boot.
#   L2  ~/.termux/boot/{sshd,adb,termuxservices} (FALLBACK via Termux:Boot app;
#         root steps are skipped silently when su is unavailable)
#   L3  $HOME/.termux/termux.properties          allow-external-apps = true
#         REQUIRED by L1: termux blocks external RunCommand intents otherwise.
#
# Two extras that fix live bugs found on 2026-10-18 (see the single scripts):
#   root-boot/20-noautoapps.sh  → boot guard, force-stops apps that come back on
#         their own (Firefox ~1 GB, Play Store 3 processes, Calendar, Contacts, MMRL)
#   termux-services-guard.sh    → liveness check in termux-services' service-daemon,
#         otherwise every login shell spawns a second runsvdir plus 8 zombies

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
# WHY backup OUTSIDE ~/.termux/boot: Termux:Boot runs EVERY executable file in that
# directory, so an in-place ".bak" copy with mode 700 would be executed as well.
# That happened live on 2026-10-18: a stale backup re-added "sv up sshd" and the
# port-8022 bind loop came back.
if [ -f "$HOME/.termux/boot/termuxservices" ]; then
    mkdir -p "$HOME/.termux-boot-backup"
    cp -a "$HOME/.termux/boot/termuxservices" \
        "$HOME/.termux-boot-backup/termuxservices.$(date +%Y%m%d-%H%M%S)"
fi
install -m 700 ./termuxservices "$HOME/.termux/boot/termuxservices"
echo "Termux:Boot fallback scripts in ~/.termux/boot/ (sshd, adb, termuxservices)"
echo "  NOTE: Termux:Boot app must be opened once so BOOT_COMPLETED is received."

# --- Termux service manager: duplicate-runsvdir guard ---------------------------
# WHY: profile.d/start-services.sh calls "service-daemon start" per login shell and
# the upstream start() does not check whether runsvdir is alive.
if [ -f ./termux-services-guard.sh ]; then
    chmod +x ./termux-services-guard.sh
    ./termux-services-guard.sh || echo "root: termux-services-guard skipped" >&2
fi

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
    # WHY this guard: these apps restart themselves after a boot although they are
    # only needed on demand (~1.4 GB RSS plus CPU on a Pixel 8). It force-stops them
    # 90 s after boot and skips any app that is in the foreground right then.
    if su -c "cat > /data/adb/service.d/20-noautoapps.sh" < ./root-boot/20-noautoapps.sh; then
        su -c "chmod 700 /data/adb/service.d/20-noautoapps.sh"
        echo "root: boot guard installed (edit PKGS at the top of 20-noautoapps.sh per device)"
    else
        echo "root: ERROR while writing the boot guard" >&2
    fi
    # WHY re-assert at boot: the RustDesk/Tailscale app-ops (PROJECT_MEDIA,
    # ACTIVATE_VPN) survive a reboot on their own, but a ROM update or Android's
    # "reset app preferences" clears them — RustDesk would then show the
    # "Start recording or casting" consent dialog again. Skips missing packages.
    if su -c "cat > /data/adb/service.d/30-apps.sh" < ./root-boot/30-apps.sh; then
        su -c "chmod 700 /data/adb/service.d/30-apps.sh"
        echo "root: app-grant boot script installed (RustDesk/Tailscale)"
    else
        echo "root: ERROR while writing the app-grant boot script" >&2
    fi
else
    echo "root: no su available — L1 skipped, L2 fallback stays in place"
fi
