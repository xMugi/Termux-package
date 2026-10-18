#!/system/bin/sh
# Termux/SSH autostart + anti-kill hardening — runs as ROOT from /data/adb/service.d
# (Magisk/KernelSU both execute this at boot). Device-agnostic on purpose:
#   - Android 12/13 keys (device_config max_phantom_processes) are guarded
#   - Android 15/16 keys (settings_enable_monitor_phantom_procs, fflag override,
#     activity_manager_native_boot use_freezer) are added
#   - every call is failure-tolerant: a missing key must never abort the script
# Verified live on Note10P (Android 12, KernelSU) and Pixel 8 (Android 16, Magisk).

# --- 1) wait for boot completion ------------------------------------------------
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 90 ]; do i=$((i+1)); sleep 1; done
sleep 15  # let zygote/ActivityManager/init settle before am/setprop calls

# --- 2) wireless ADB on 7777 (RustDesk elevation, adb over TCP) -----------------
setprop service.adb.tcp.port 7777
stop adbd
start adbd

# --- 3) anti-kill switches ------------------------------------------------------
# WHY set_sync_disabled_for_tests FIRST: otherwise GMS DeviceConfig sync silently
# reverts the values within minutes / at reboot.
device_config set_sync_disabled_for_tests persistent
# A12/13 phantom limit (deprecated on A15+, kept for older ROMs)
device_config put activity_manager max_phantom_processes 2147483647
# A12L-16 master switch for the phantom process killer (this is the one that
# actually kills Termux sshd/runsv children as "Trimming phantom processes")
settings put global settings_enable_monitor_phantom_procs false
# fflag override twin (some ROMs read the property instead of the settings row)
setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false
# cached-apps freezer: legacy global key + AOSP native_boot key (A15/16);
# takes effect after the NEXT boot (cgroup init happens early in boot)
settings put global cached_apps_freezer disabled
device_config put activity_manager_native_boot use_freezer false

# --- 4) battery / doze / standby exemptions ------------------------------------
dumpsys deviceidle whitelist +com.termux
dumpsys deviceidle whitelist +com.termux.boot
appops set com.termux RUN_IN_BACKGROUND allow
appops set com.termux RUN_ANY_IN_BACKGROUND allow
appops set com.termux START_FOREGROUND allow
appops set com.termux auto_revoke_permissions_if_unused ignore 2>/dev/null \
  || appops set com.termux AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore 2>/dev/null
am set-inactive com.termux false

# --- 5) Termux bootstrap in its OWN uid/SELinux context -------------------------
# WHY not "su -c sshd": files/ports must belong to the Termux uid; a root-launched
# sshd mixes root-owned files into $HOME. RunCommandService runs inside Termux's
# own process context. Requires "allow-external-apps = true" in termux.properties.
am startservice --user 0 -n com.termux/com.termux.app.TermuxService -a com.termux.service_wake_lock
sleep 3
am startservice --user 0 -n com.termux/com.termux.app.RunCommandService -a com.termux.RUN_COMMAND \
  --es com.termux.RUN_COMMAND_PATH /data/data/com.termux/files/usr/bin/sshd \
  --es com.termux.RUN_COMMAND_WORKDIR /data/data/com.termux/files/home \
  --ez com.termux.RUN_COMMAND_BACKGROUND true

exit 0
