#!/data/data/com.termux/files/usr/bin/bash
# termux-apps.sh — RustDesk and Tailscale as APKs, plus the root-side grants that
# make them work unattended. Termux cannot run either one natively: both are GUI
# apps (Flutter / Android VPN service), so they are installed as apps and only the
# settings Android needs are scripted here.
#
# Usage (in Termux, root required):
#   bash termux-apps.sh                  # install/update both, apply all grants
#   bash termux-apps.sh rustdesk         # only RustDesk
#   bash termux-apps.sh tailscale        # only Tailscale
#   bash termux-apps.sh verify           # report state, change nothing
#   bash termux-apps.sh --no-install     # grants only, no download/install
#   bash termux-apps.sh rustdesk --reinstall   # force reinstall at the same version
#   bash termux-apps.sh tailscale --replace     # remove the existing app, then install
#   bash termux-apps.sh anydesk-off      # switch away from AnyDesk (disable + drop grants)
#   bash termux-apps.sh anydesk-off --uninstall  # remove the AnyDesk packages instead
#   bash termux-apps.sh anydesk-restore  # enable AnyDesk again
#   bash termux-apps.sh rustdesk-restart # client stuck at "waiting for image"? fresh capture
#   RUSTDESK_VERSION=1.5.0 TAILSCALE_VERSION=1.104.1 bash termux-apps.sh   # pin versions
#
# Sources: GitHub releases only — github.com/rustdesk/rustdesk and
# github.com/tailscale/tailscale-android. No account needed, no mirror;
# the sha256 comes from the GitHub API digest of the release asset.
#
# AUTOMATIC:  APK download + install, app-ops, Doze whitelist, RustDesk accessibility
#             service and start-on-boot flag, Tailscale VPN-consent skip.
# MANUAL:     Tailscale login (browser or auth key), RustDesk password/PIN, and the
#             first app start.
#
# WHY the app-ops matter:
#   PROJECT_MEDIA (RustDesk)  — without it Android shows "Start recording or casting
#                               with RustDesk?" on every screen-share start. allow =
#                               no dialog, verified on the Note10P (Android 15).
#   ACTIVATE_VPN (Tailscale)  — without it Android asks for the VPN connection and
#                               that dialog breaks unattended start after a reboot.

set -eu
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
RD_PKG=com.carriez.flutter_hbb
RD_A11Y=${RD_PKG}/.InputService        # RustDesk's input control IS an AccessibilityService
TS_PKG=com.tailscale.ipn
# Both AnyDesk flavours seen on the phones: the main app and the AD1 control app.
# Either or both can be present; every step skips packages that are not installed.
AD_PKGS="com.anydesk.anydeskandroid com.anydesk.adcontrol.ad1"
CACHE="$HOME/.cache/termux-apps"
RD_VER="${RUSTDESK_VERSION:-}"
TS_VER="${TAILSCALE_VERSION:-}"

say() { printf '%s\n' "$*"; }
# Root helper: exactly one argument, the complete remote command.
r() { su -c "$1"; }
have_root() { su -c id >/dev/null 2>&1; }
installed_ver() { r "dumpsys package $1" 2>/dev/null | sed -n 's/.*versionName=\(.*\)/\1/p' | head -1; }
appop() { r "cmd appops get $1 $2" 2>/dev/null | sed -n 's/.*: *\([a-z]*\).*/\1/p' | head -1; }

set_appop()   { r "cmd appops set $1 $2 $3" 2>/dev/null || true; }
set_doze()    { r "dumpsys deviceidle whitelist +$1" >/dev/null 2>&1 || true; }
set_bg()      { r "cmd appops set $1 RUN_IN_BACKGROUND allow" >/dev/null 2>&1 || true; }
# WHY dumpsys instead of the secure setting: Android trims entries it considers
# invalid right after an install/update, so the setting alone lies.
a11y_have()   { r "dumpsys accessibility" 2>/dev/null | grep -m1 'Enabled services' | grep -q "$RD_PKG"; }

# --- downloads -----------------------------------------------------------------
fetch() { # $1 = url, $2 = target file
    mkdir -p "$CACHE"
    if [ -s "$2" ] && [ "${FORCE:-0}" != 1 ]; then say "  cached: $(basename "$2")"; return 0; fi
    say "  download: $(basename "$2")"
    curl -fL --retry 3 -o "$2.part" "$1"
    mv "$2.part" "$2"
}
rd_arch() { # RustDesk ships one APK per ABI
    case "$(uname -m)" in
        aarch64) echo aarch64 ;;
        armv7l|armv8l) echo armv7 ;;
        x86_64) echo x86_64 ;;
        *) say "unsupported architecture: $(uname -m)" >&2; exit 2 ;;
    esac
}
latest_rd() { curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest 2>/dev/null \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1; }
# WHY GitHub only: same Tailscale-signed APK, no account needed, and the GitHub API
# carries the sha256 digest of the asset — no separate checksum file to maintain.
# A pinned TAILSCALE_VERSION is matched against the asset names, because the release
# tag carries a build suffix ("1.104.1-t7f4efe814-g6d75bd403").
TS_API=https://api.github.com/repos/tailscale/tailscale-android
ts_meta() { # sets TS_META_VER / TS_META_URL / TS_META_SHA
    local j lines line pat
    TS_META_VER=""; TS_META_URL=""; TS_META_SHA=""
    j=$(curl -fsSL "$TS_API/releases?per_page=20" 2>/dev/null || true)
    # The API answers pretty-printed JSON: flatten it first, then cut at every asset
    # name so one candidate line holds the name plus that asset's digest and URL.
    lines=$(printf '%s' "$j" | tr -d '\n' | sed 's/"name": *"tailscale-android-universal/\n&/g')
    if [ -n "$TS_VER" ]; then pat="universal-$TS_VER\.apk"; else pat='universal-[0-9.]+\.apk'; fi
    line=$(printf '%s' "$lines" | grep -E "$pat" | head -1 | cut -c1-3000)
    if [ -n "$line" ]; then
        TS_META_VER=$(printf '%s' "$line" | grep -oE 'universal-[0-9.]+\.apk' | head -1 | sed 's/universal-//; s/\.apk//')
        TS_META_URL=$(printf '%s' "$line" | grep -o 'https://github.com/[^"]*\.apk' | head -1)
        TS_META_SHA=$(printf '%s' "$line" | grep -o 'sha256:[0-9a-f]\{64\}' | head -1 | cut -d: -f2)
    fi
    [ -n "$TS_META_URL" ] || { say "  ERROR: no Tailscale APK asset from the GitHub API"; return 1; }
}
verify_sha256() { # $1 = file, $2 = expected hex digest (empty = skip)
    [ -n "$2" ] || return 0
    local got; got=$(sha256sum "$1" | cut -d' ' -f1)
    if [ "$got" = "$2" ]; then say "  sha256 ok"; else say "  ERROR: sha256 mismatch"; return 1; fi
}

# --- install -------------------------------------------------------------------
install_apk() { # $1 = local path, $2 = package
    # WHY /data/local/tmp: root reads that path without fighting Termux's SELinux
    # context; installd picks the APK up from there like from any normal installer.
    local tmp="/data/local/tmp/$(basename "$1")"
    r "cp '$1' '$tmp'" || { say "  copy failed"; return 1; }
    r "pm install -r -d '$tmp'" >"$CACHE/install.log" 2>&1 || true
    r "rm -f '$tmp'"
    if grep -q Success "$CACHE/install.log"; then say "  installed: $2 -> $(installed_ver "$2")"
    else
        say "  install failed:"
        sed 's/^/    /' "$CACHE/install.log"
        # WHY the hint: an existing installation that was signed with another key
        # (any APK re-signed outside the project) cannot be replaced in place.
        grep -q 'UPDATE_INCOMPATIBLE\|signatures do not match' "$CACHE/install.log" \
            && say "  hint: existing package is signed with a different key - remove it with --replace"
        return 1
    fi
}
replace_pkg() { # $1 = package: drop the existing installation so the APK can replace it
    say "  --replace: removing $1 (its app data and login are lost)"
    r "pm uninstall $1" >/dev/null 2>&1 || true
}

# --- RustDesk ------------------------------------------------------------------
rd_start_on_boot() {
    # The app flag "start on boot" is a Flutter preference; set it while the app is
    # stopped, otherwise it overwrites the file on its next write. Failure-tolerant:
    # if the key is missing we only print a hint instead of aborting the script.
    # WHY start the app afterwards: "am force-stop" puts the package in the stopped
    # state, and Android then drops its accessibility entry — starting it once puts
    # the package back to normal so the next step (accessibility) actually sticks.
    local pref="/data/data/$RD_PKG/shared_prefs/KEY_SHARED_PREFERENCES.xml"
    r "am force-stop $RD_PKG" >/dev/null 2>&1 || true
    if r "grep -q KEY_START_ON_BOOT_OPT '$pref'" 2>/dev/null; then
        r "sed -i 's|KEY_START_ON_BOOT_OPT\" value=\"false|KEY_START_ON_BOOT_OPT\" value=\"true|' '$pref'"
    else
        say "  hint: enable 'start on boot' once inside RustDesk (pref key not found)"
    fi
    r "am start -n $RD_PKG/.MainActivity" >/dev/null 2>&1 || true
    sleep 4
}
rd_a11y() {
    # Append instead of overwrite: other apps (AnyDesk) keep their service.
    # WHY the retry: right after "pm install" the service is not registered yet and
    # Android silently drops the entry from the list (observed 2026-10-18), so we
    # write, wait and re-check up to three times. Bounded, never blocks the script.
    local cur new i
    for i in 1 2 3; do
        a11y_have && { say "  accessibility: enabled (dumpsys)"; return 0; }
        cur=$(r "settings get secure enabled_accessibility_services" 2>/dev/null)
        case "$cur" in
            *$RD_PKG*) new="$cur" ;;
            *) new="${cur:+$cur:}$RD_A11Y" ;;
        esac
        r "settings put secure enabled_accessibility_services '$new'" >/dev/null 2>&1 || true
        r "settings put secure accessibility_enabled 1" >/dev/null 2>&1 || true
        sleep 3
    done
    say "  warning: accessibility entry did not stick - enable RustDesk once in Settings -> Accessibility"
}
rustdesk() {
    local ver arch url apk
    ver="$RD_VER"; [ -n "$ver" ] || ver=$(latest_rd)
    [ -n "$ver" ] || ver=1.5.0                       # fallback when the API is unreachable
    arch=$(rd_arch)
    apk="$CACHE/rustdesk-$ver-$arch-signed.apk"
    url="https://github.com/rustdesk/rustdesk/releases/download/$ver/rustdesk-$ver-$arch-signed.apk"
    say "RustDesk $ver ($arch)"
    if [ "$INSTALL" = 1 ]; then
        if [ "${REPLACE:-0}" = 1 ] && [ -n "$(installed_ver "$RD_PKG")" ]; then replace_pkg "$RD_PKG"; fi
        if [ "$(installed_ver "$RD_PKG")" != "$ver" ] || [ "${REINSTALL:-0}" = 1 ]; then
            fetch "$url" "$apk"; install_apk "$apk" "$RD_PKG" || true
        else say "  already installed: $ver"
        fi
    fi
    set_appop "$RD_PKG" PROJECT_MEDIA allow            # no "Start recording or casting?" dialog
    set_appop "$RD_PKG" SYSTEM_ALERT_WINDOW allow       # floating helper window
    set_doze "$RD_PKG"; set_bg "$RD_PKG"
    rd_start_on_boot        # stop app, set the pref, start it again (leaves the stopped state)
    rd_a11y                 # WHY last: a11y entries only stick for non-stopped packages
}
# --- Tailscale -----------------------------------------------------------------
tailscale() {
    local ver url apk
    ts_meta || return 1
    ver="$TS_META_VER"; url="$TS_META_URL"
    apk="$CACHE/tailscale-android-universal-$ver.apk"
    say "Tailscale $ver"
    if [ "$INSTALL" = 1 ]; then
        if [ "${REPLACE:-0}" = 1 ] && [ -n "$(installed_ver "$TS_PKG")" ]; then replace_pkg "$TS_PKG"; fi
        if [ "$(installed_ver "$TS_PKG")" != "$ver" ] || [ "${REINSTALL:-0}" = 1 ]; then
            fetch "$url" "$apk"
            verify_sha256 "$apk" "$TS_META_SHA" || say "  warning: continuing with an unverified download"
            # WHY "|| true": a refused install (foreign signature) must not stop the
            # grants below - the installed app needs them either way.
            install_apk "$apk" "$TS_PKG" || true
        else
            say "  already installed: $ver"
        fi
    fi
    set_appop "$TS_PKG" ACTIVATE_VPN allow              # no VPN consent dialog
    set_doze "$TS_PKG"; set_bg "$TS_PKG"
}

rd_restart() {
    # Recovery for the client hanging at "waiting for image".
    # WHY this happens: with PROJECT_MEDIA allow Android *continues* an existing
    # MediaProjection instead of stopping it (log: "MediaProjectionStopController:
    # Continuing MediaProjection for package with OP_PROJECT_MEDIA AppOp"). So when
    # RustDesk's capture service dies - client disconnect, lock, a second capture tool
    # such as scrcpy - the app keeps a session but no virtual display, never gets the
    # stop callback and never asks for a new projection. It then waits forever.
    # Force-stop + start makes RustDesk request a fresh projection; the app-op still
    # skips the consent dialog. Measured on the Pixel 8: virtual display back, ON.
    say "restarting RustDesk for a fresh MediaProjection"
    rd_start_on_boot        # force-stop -> write the pref -> start (leaves the stopped state)
    # WHY this must follow: force-stop also drops the accessibility entry, and without
    # it the client shows the image but cannot control input ("Input control" disabled).
    # Measured on the Pixel 8, 2026-10-18: after the first restart the entry was gone.
    sleep 3
    rd_a11y
    say "  projection session: $(proj_session)"
    say "  virtual display:    $(proj_vd)  (ON = frames flowing, OFF/none = connect again)"
    say "  accessibility:      $(a11y_have && echo enabled || echo 'DISABLED - input control off')"
}
# Capture state, split in two checks on purpose: a session alone means nothing.
proj_session() { r "dumpsys media_projection" 2>/dev/null | grep -q "$RD_PKG" && echo present || echo absent; }
proj_vd() { # ON / OFF / none for RustDesk's virtual display
    local l s
    l=$(r "dumpsys display" 2>/dev/null | grep -m1 'RustDeskVD.*type VIRTUAL' || true)
    if [ -z "$l" ]; then echo none; return 0; fi
    s=$(printf '%s' "$l" | sed -n 's/.*, state \([A-Z]*\),.*/\1/p')
    echo "${s:-unknown}"
}

# --- AnyDesk removal (switch to RustDesk) --------------------------------------
# WHY: installing RustDesk is only half of the swap. AnyDesk keeps its accessibility
# service (remote input), its Doze whitelist entry and its app-ops - above all
# PROJECT_MEDIA allow, which removes the screen-share consent dialog. Left in place it
# would stay remotely usable. Disabling (default) instead of uninstalling: reversible,
# keeps the app data, and it stops every AnyDesk component at once.
ad_state() { # $1 = package -> "disabled" | "enabled" | "" (not installed)
    [ -n "$(installed_ver "$1")" ] || return 0
    if r "pm list packages -d" 2>/dev/null | grep -q "package:$1$"; then echo disabled; else echo enabled; fi
}
ad_drop_a11y() {
    # Remove only the AnyDesk entries, keep RustDesk and everything else.
    local cur new
    cur=$(r "settings get secure enabled_accessibility_services" 2>/dev/null || true)
    [ -n "$cur" ] || { say "  accessibility: empty, nothing to do"; return 0; }
    new=$(printf '%s' "$cur" | tr ':' '\n' | grep -v '^com\.anydesk' | tr '\n' ':' || true)
    new=${new%:}
    if [ "$new" = "$cur" ]; then say "  accessibility: no AnyDesk entry"; return 0; fi
    r "settings put secure enabled_accessibility_services '$new'" >/dev/null 2>&1 || true
    say "  accessibility: AnyDesk entry removed"
}
anydesk_off() {
    local p done=0
    for p in $AD_PKGS; do
        [ -n "$(installed_ver "$p")" ] || continue
        done=1
        r "am force-stop $p" >/dev/null 2>&1 || true
        if [ "${UNINSTALL:-0}" = 1 ]; then
            if r "pm uninstall $p" >/dev/null 2>&1; then say "  uninstalled: $p"
            else say "  uninstall failed: $p (still active as device admin or profile owner?)"; fi
        else
            if r "pm disable-user --user 0 $p" >/dev/null 2>&1; then say "  disabled: $p"
            else say "  disable failed: $p"; fi
        fi
        # Doze entry, app-ops back to default: no unattended screen sharing any more.
        r "dumpsys deviceidle whitelist -$p" >/dev/null 2>&1 || true
        set_appop "$p" PROJECT_MEDIA default
        set_appop "$p" SYSTEM_ALERT_WINDOW default
        set_appop "$p" RUN_IN_BACKGROUND default
        set_appop "$p" RUN_ANY_IN_BACKGROUND default
    done
    [ "$done" = 1 ] || say "  AnyDesk: not installed"
    ad_drop_a11y
    say "  back: bash $0 anydesk-restore"
}
anydesk_restore() {
    local p
    for p in $AD_PKGS; do
        [ -n "$(installed_ver "$p")" ] || continue
        r "pm enable $p" >/dev/null 2>&1 || true
        say "  enabled: $p"
    done
    say "  note: the accessibility entry has to be switched on again in Settings -> Accessibility"
}

# --- verify --------------------------------------------------------------------
verify() {
    local p v
    for p in "$RD_PKG" "$TS_PKG"; do
        v=$(installed_ver "$p")
        if [ -z "$v" ]; then say "$p: not installed"; continue; fi
        say "$p: $v"
        case "$p" in
            "$RD_PKG") op=PROJECT_MEDIA ;;
            "$TS_PKG") op=ACTIVATE_VPN ;;
        esac
        say "  $op: $(appop "$p" "$op")"
        say "  doze whitelist: $(r "dumpsys deviceidle whitelist" 2>/dev/null | grep -c "$p")"
    done
    say "accessibility (dumpsys): $(a11y_have && echo 'RustDesk enabled' || echo 'RustDesk NOT enabled')"
    say "accessibility (setting): $(r "settings get secure enabled_accessibility_services" 2>/dev/null)"
    for p in $AD_PKGS; do
        s=$(ad_state "$p")
        if [ -n "$s" ]; then say "$p: $(installed_ver "$p") ($s)"; fi
    done
    say "start-on-boot pref: $(r "grep -o 'KEY_START_ON_BOOT_OPT\" value=\"[a-z]*' /data/data/$RD_PKG/shared_prefs/KEY_SHARED_PREFERENCES.xml" 2>/dev/null || echo 'n/a')"
    say "capture session: $(proj_session) / virtual display: $(proj_vd)  (client 'waiting for image' = session present, display OFF)"
}

# --- main ----------------------------------------------------------------------
INSTALL=1
TARGETS=""
for a in "$@"; do
    case "$a" in
        --no-install) INSTALL=0 ;;
        --force) FORCE=1 ;;
        --reinstall) REINSTALL=1 ;;
        --replace) REPLACE=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
        rustdesk|tailscale|verify) TARGETS="$TARGETS $a" ;;
        anydesk-off) TARGETS="$TARGETS anydesk_off" ;;
        anydesk-restore) TARGETS="$TARGETS anydesk_restore" ;;
        rustdesk-restart) TARGETS="$TARGETS rd_restart" ;;
        *) say "unknown option: $a" >&2; exit 2 ;;
    esac
done
[ -n "$TARGETS" ] || TARGETS=" rustdesk tailscale"

if ! have_root; then say "root required (su -c id failed). Nothing changed." >&2; exit 1; fi
for t in $TARGETS; do $t; done
[ "$TARGETS" = " verify" ] && exit 0
say ""
say "state:"
verify
say ""
say "manual steps: Tailscale login in the app (browser or auth key), RustDesk password/PIN,"
say "and one first app start. RustDesk: 'start on boot' + accessibility = unattended."
