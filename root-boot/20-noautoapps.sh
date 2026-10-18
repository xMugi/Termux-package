#!/system/bin/sh
# 20-noautoapps.sh — boot guard: force-stops apps that come back on their own after
# a reboot although they are only needed on demand. Deployed to
# /data/adb/service.d/ (Magisk and KernelSU run every script there at boot), 0700 root.
# Remove:  rm /data/adb/service.d/20-noautoapps.sh
# Log:     /data/adb/noautoapps.log
#
# WHY this list (measured on a Pixel 8, 2026-10-18, root snapshot):
#   org.mozilla.fenix            ~1 GB RSS, returns with its tab processes
#   com.android.vending          3 processes ~525 MB RSS; vending:background had
#                                burnt 2:32 CPU since boot (only system_server was higher)
#   com.google.android.calendar  45 MB PSS, only needed on demand
#   com.google.android.contacts  42 MB PSS (learning_bg process)
#   com.dergoogler.mmrl          30 MB PSS (module repo loader, rarely opened)
#
# Pairing: "cmd appops set --user 0 <pkg> RUN_ANY_IN_BACKGROUND ignore" keeps those
# apps from returning in the background in the first place; this guard clears what is
# already up after a boot. PKGS is a starting point — edit it per device.
#
# The guard runs 90 s after boot and only force-stops an app that is NOT in the
# foreground, so a manual start is never interrupted. am force-stop is idempotent,
# which is why it does not collide with the killer() pass of the TSupport module.

LOG=/data/adb/noautoapps.log
PKGS="org.mozilla.fenix com.android.vending com.google.android.calendar com.google.android.contacts com.dergoogler.mmrl"

sleep 90

resumed=$(/system/bin/dumpsys activity activities 2>/dev/null | grep -m1 "ResumedActivity")
for pkg in $PKGS; do
  case "$resumed" in
    *"$pkg"*)
      echo "$(date '+%F %T') $pkg in foreground - no force-stop" >> "$LOG"
      ;;
    *)
      /system/bin/am force-stop "$pkg"
      echo "$(date '+%F %T') $pkg force-stopped (ResumedActivity: ${resumed:-unknown})" >> "$LOG"
      ;;
  esac
done
