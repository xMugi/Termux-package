#!/data/data/com.termux/files/usr/bin/bash
# komodo/install.sh — Komodo Periphery on Android/Termux. Idempotent.
#
# WHY glibc-runner: the official periphery-aarch64 binary is a GNU/Linux build and
# wants /lib/ld-linux-aarch64.so.1, which Android (bionic) does not have. "grun"
# supplies the loader — no proot, no distro, no docker.
#
# What it creates:
#   ~/.config/komodo/periphery.config.toml    config (0600)
#   ~/.local/share/komodo/bin/periphery-<v>   binary + "periphery" symlink
#   ~/.local/share/komodo/data/               keys (server identity), stacks, repos
#   $PREFIX/var/service/komodo                runsv service: auto-restart, sv control,
#                                             svlogd log rotation
#   ~/.termux/boot/90-komodo                  Termux:Boot entry
#
# Usage:
#   install.sh --connect-as PIXEL8 --core ws://unraid:9120 --onboarding-key -
#   install.sh                       # reinstall/repair, existing config + keys kept
#   install.sh --version v2.3.4      # update the agent, then restart
#
# Options: --connect-as NAME  --core ws://host:port  --onboarding-key KEY|-
#          --version vX.Y.Z  --force (regenerate the config)

set -eu
cd "$(dirname "$0")"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
CONF="$HOME/.config/komodo/periphery.config.toml"
BIN_DIR="$HOME/.local/share/komodo/bin"
BIN_LINK="$BIN_DIR/periphery"
DATA="$HOME/.local/share/komodo/data"
SVC="$PREFIX/var/service/komodo"
OLD_INSTALL="${KOMODO_ADOPT_DIR:-$HOME/komodo-test}"

CONNECT_AS=""
CORE="ws://unraid:9120"              # Core host as the phone sees it: LAN hostname by
                                     # default, or a Tailscale IP/MagicDNS name when the
                                     # agent has to work outside the home network
VERSION="v2.3.3"
KEY=""
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --connect-as)     CONNECT_AS="$2"; shift 2 ;;
        --core)           CORE="$2"; shift 2 ;;
        --onboarding-key) KEY="$2"; shift 2 ;;
        --version)        VERSION="$2"; shift 2 ;;
        --force)          FORCE=1; shift ;;
        -h|--help)        sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

# --- prerequisites (only what is missing) -------------------------------------
need=""
for p in curl grun svlogd; do command -v "$p" >/dev/null 2>&1 || need="$need $p"; done
case "$need" in
    *grun*)   pkgs="curl glibc-repo glibc-runner termux-services" ;;
    *svlogd*) pkgs="termux-services" ;;
    *curl*)   pkgs="curl" ;;
    *)        pkgs="" ;;
esac
[ -n "$pkgs" ] && { echo "installing:$pkgs"; pkg install -y $pkgs; }

mkdir -p "$HOME/.config/komodo" "$BIN_DIR" "$DATA" "$HOME/.local/bin" "$HOME/.local/state/komodo"
chmod 700 "$DATA"

# --- server identity ----------------------------------------------------------
# WHY copy the old keys: the private key IS the server identity in Komodo Core.
# Regenerating it would create a second server entry and need a new onboarding key.
if [ ! -s "$DATA/keys/periphery.key" ] && [ -d "$OLD_INSTALL/data/keys" ]; then
    cp -a "$OLD_INSTALL/data/keys" "$DATA/keys"
    chmod 700 "$DATA/keys" "$DATA/keys"/*
    echo "identity: keys taken over from $OLD_INSTALL"
fi

# --- binary (versioned, switchable) -------------------------------------------
BIN="$BIN_DIR/periphery-$VERSION"
if [ ! -x "$BIN" ]; then
    echo "downloading periphery $VERSION"
    curl -fL --retry 3 -o "$BIN.part" \
        "https://github.com/moghtech/komodo/releases/download/$VERSION/periphery-aarch64"
    mv "$BIN.part" "$BIN"
    chmod 700 "$BIN"
fi
ln -sfn "$BIN" "$BIN_LINK"
echo "binary: $(grun "$BIN" --version 2>/dev/null | tail -1)"

# --- config -------------------------------------------------------------------
if [ -f "$CONF" ] && [ "$FORCE" = 0 ]; then
    echo "config kept: $CONF (use --force to regenerate)"
else
    # adopt values from a legacy install when not given on the command line
    if [ -f "$OLD_INSTALL/periphery.config.toml" ]; then
        [ -n "$CONNECT_AS" ] || CONNECT_AS="$(sed -n 's/^[[:space:]]*connect_as[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$OLD_INSTALL/periphery.config.toml" | head -1)"
        [ -z "$KEY" ] && KEY="$(sed -n 's/^[[:space:]]*onboarding_key[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$OLD_INSTALL/periphery.config.toml" | head -1)"
    fi
    [ -n "$CONNECT_AS" ] || { echo "ERROR: --connect-as NAME required for a new install" >&2; exit 2; }
    if [ "$KEY" = "-" ]; then
        printf 'onboarding key (hidden): ' >&2; read -rs KEY; printf '\n' >&2
    fi
    umask 077
    cat > "$CONF.tmp" <<EOF
# Komodo Periphery on Termux. Reinstall: komodo/install.sh   Update: --version vX.Y.Z
# WHY under \$HOME: /etc is read-only on Android (would give "Read-only file system").
root_directory = "$DATA"

# Outbound only: Periphery dials Core, nothing listens on the phone.
core_address = "$CORE"
connect_as = "$CONNECT_AS"
$( [ -n "$KEY" ] && printf 'onboarding_key = "%s"\n' "$KEY" )
server_enabled = false

# Shell for the Komodo UI terminals. Periphery shlex-splits this string and spawns it
# directly, so it must be an existing program; the child inherits HOME/PATH/TERM.
default_terminal_command = "$PREFIX/bin/bash"
disable_terminals = false
# No docker daemon on Android; the schema has no disable_docker switch.
disable_container_terminals = true
container_stats_polling_rate = "30-day"
stats_polling_rate = "5-sec"

# Android reports dozens of virtual mounts; only these give sane numbers.
include_disk_mounts = ["/", "/storage/emulated"]

logging.level = "info"
EOF
    # WHY validate: a duplicated TOML key makes Periphery drop the WHOLE config, fall
    # back to /etc/komodo and die with "Read-only file system (os error 30)".
    if python -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" "$CONF.tmp"; then
        mv "$CONF.tmp" "$CONF"; chmod 600 "$CONF"
        echo "config written: $CONF"
    else
        rm -f "$CONF.tmp"; echo "ERROR: generated config invalid, keeping the old one" >&2; exit 1
    fi
fi

# --- service (runsv) + boot entry --------------------------------------------
# WHY mkdir: on a fresh device neither the service dir nor its log subdir exists;
# `install` does not create parent directories and would abort the script.
mkdir -p "$SVC/log" "$HOME/.termux/boot"
install -m 700 "$(dirname "$0")/service/run"    "$SVC/run"
install -m 700 "$(dirname "$0")/service/finish" "$SVC/finish"
install -m 700 "$(dirname "$0")/service/log/run" "$SVC/log/run"
install -m 700 "$(dirname "$0")/boot/komodo"    "$HOME/.termux/boot/90-komodo"

# --- restart ------------------------------------------------------------------
# WHY service-daemon: runsvdir is normally started by a login shell's profile; after
# a fresh install there may be none yet.
pgrep -f runsvdir >/dev/null 2>&1 || service-daemon start >/dev/null 2>&1 || true
sv up "$SVC"
sleep 2
sv status "$SVC"

cat <<'EOF'

done. control + update:
  sv status $PREFIX/var/service/komodo     # run/down + pid
  sv down|up $PREFIX/var/service/komodo    # stop/start (auto-restart while up)
  tail -f ~/.local/state/komodo/log/current
  bash install.sh --version vX.Y.Z         # update agent (config + keys untouched)
EOF
