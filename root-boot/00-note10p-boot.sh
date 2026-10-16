#!/system/bin/sh
# /system/bin/sh: Android-Shell — Script läuft als ROOT via KernelSU service.d, vor jedem Termux-Kontext.
# Warum service.d: Läuft on-boot automatisch (KernelSU/Magisk-Module unterstützen beide /data/adb/service.d).
# Warum alles hier als root (und NICHT über Termux:Boot): setprop/dumpsys/settings brauchen root; Termux-UID (u0_aXXX)
# darf Sicherheits-Properties nicht schreiben. Termux:Boot bleibt damit ungenutzt.

# --- Boot-Completion-Wait -------------------------------------------------------
# Warum: service.d kann feuern bevor sys.boot_completed=1; ohne Wait schlagen am/setprop fehl.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 90 ]; do i=$((i+1)); sleep 1; done
sleep 15  # System-Services (zygote, ActivityManager, init) laufen lassen

# --- 1) adbd auf TCP 7777 (für RustDesk "Start"-Button) --------------------------
# Warum: RustDesk nutzt TCP-ADB, um sich selbst zu elevater; ohne dies klickt man sonst IMMER
# manuell setprop+stop+start in der Magisk-SSH. LAN-only (192.168.x), ADBkodiert RSA-Auth.
setprop service.adb.tcp.port 7777
stop adbd
start adbd

# --- 2) Killer entschärfen (Android 12+) -----------------------------------------
# Warum: Phantom Process Killer killtCHILD-Prozesse (sshd!) >30s lifetime über Limit; der
# Cached-Apps-Freezer friert Hintergrund-Apps ein (Termux+sshd dzdann eingefroren).
# Reihenfolge WICHTIG: set_sync_disabled_for_tests ZUERST, sonst überschreibt GMS-DeviceConfig-Sync
# den Wert binnen Minuten/beim Reboot wieder.
device_config set_sync_disabled_for_tests persistent
device_config put activity_manager max_phantom_processes 2147483647
# settings_enable_monitor_phantom_procs: AOSP-Master-Switch ab 12L; auf manchen ROMs unset -> Fehler ist ok
settings put global settings_enable_monitor_phantom_procs false
# Cached-Apps-Freezer: braucht EINEN Reboot, danach dauerhaft aktiv & berseht Reboots
settings put global cached_apps_freezer disabled

# --- 3) Akku-Exemptions für Termux ------------------------------------------------
# Warum: Doze/App-Standby suspendiert TERMUX-Prozesse auch ohne Kill -> sshd antwortet nicht.
# auto_revoke: verhindert Auto-Reset der App (Permission-Bereinigung).
dumpsys deviceidle whitelist +com.termux
dumpsys deviceidle whitelist +com.termux.boot
appops set com.termux RUN_IN_BACKGROUND allow
appops set com.termux RUN_ANY_IN_BACKGROUND allow
appops set com.termux START_FOREGROUND allow
appops set com.termux auto_revoke_permissions_if_unused ignore 2>/dev/null \
  || appops set com.termux AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore  # ROM-abhängiger Name (niedrig->12+, hoch->älter); Fehler tolerierbar

# --- 4) Termux-Bootstrap im EIGENEN UID/SELinux-Kontext ---------------------------
# Warum im Termux-Kontext und nicht `su -c sshd`: Dateien/Ports müssen termux-UID gehören;
# root-launched sshd mischt root-Dateien unter $HOME und kappt den Termux-Bootstrap.
# allow-external-apps=true MUSS in ~/.termux/termux.properties stehen — sonst blockt Termux den Intent.
#
# 4a) Wake-Lock-FGS starten: Als root ist FGS-Start aus Background erlaubt (Whitelisted Caller).
am startservice --user 0 -n com.termux/com.termux.app.TermuxService -a com.termux.service_wake_lock
sleep 3

# 4b) sshd daemonisieren via RunCommandService (kein -D!)
am startservice --user 0 -n com.termux/com.termux.app.RunCommandService -a com.termux.RUN_COMMAND \
  --es com.termux.RUN_COMMAND_PATH /data/data/com.termux/files/usr/bin/sshd \
  --es com.termux.RUN_COMMAND_WORKDIR /data/data/com.termux/files/home \
  --ez com.termux.RUN_COMMAND_BACKGROUND true

# Optional: RustDesk UI automatisch öffnen (der "Start"-Tap bleibt manuell wegen MediaProjection-Consent)
# am start -n com.carriez.flutter_hbb/.MainActivity

exit 0
