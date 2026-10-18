#!/system/bin/sh
# Re-assert the app grants for RustDesk + Tailscale at boot — runs as ROOT from
# /data/adb/service.d (Magisk/KernelSU).
#
# WHY: app-ops survive a reboot (verified on the Note10P, 2026-10-18), but a ROM
# update or Android's "reset app preferences" clears them. RustDesk would then show
# the "Start recording or casting" consent dialog again and Tailscale the VPN prompt —
# both break unattended access. Idempotent, every call is failure-tolerant.

sleep 20

for p in com.carriez.flutter_hbb com.tailscale.ipn; do
    pm list packages 2>/dev/null | grep -q "package:$p$" || continue
    case "$p" in
        com.carriez.flutter_hbb) cmd appops set "$p" PROJECT_MEDIA allow ;;
        com.tailscale.ipn)       cmd appops set "$p" ACTIVATE_VPN allow ;;
    esac
    dumpsys deviceidle whitelist "+$p"
done

# RustDesk input control. Its accessibility entry disappears on app update, force-stop
# or "reset app preferences" while screen capture keeps working - the client then shows
# the image but cannot click or type. Android only keeps the entry for a package that is
# not in the stopped state, hence the start before writing it. Additive: existing
# entries (other accessibility services) stay untouched.
RD=com.carriez.flutter_hbb
if pm list packages 2>/dev/null | grep -q "package:$RD$"; then
    cur=$(settings get secure enabled_accessibility_services 2>/dev/null)
    case "$cur" in
        *$RD/.InputService*) ;;   # already enabled, nothing to do
        *)
            am start -n $RD/.MainActivity >/dev/null 2>&1
            sleep 5
            settings put secure enabled_accessibility_services "${cur:+$cur:}$RD/.InputService" >/dev/null 2>&1
            settings put secure accessibility_enabled 1 >/dev/null 2>&1
            ;;
    esac
fi
