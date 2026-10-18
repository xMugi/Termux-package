#!/data/data/com.termux/files/usr/bin/bash
# termux-services-guard.sh — stops termux-services from spawning a second runsvdir
# on every login shell. Idempotent, keeps a timestamped backup of the package file.
#
# WHY (measured on a Pixel 8, Android 16, 2026-10-18):
#   $PREFIX/etc/profile.d/start-services.sh calls "service-daemon start" on every
#   login shell. Upstream start() is just
#       start-stop-daemon -S -b -m -p $PIDFILE -x $DAEMON -d $PREFIX -- $DAEMON_OPTS
#   which does NOT check whether runsvdir is already alive, so every login starts a
#   second runsvdir. Its runsv children lose the supervise-lock race, exit at once
#   and stay behind as zombies — 8 per login, they accumulate in the PID table.
#
# WHAT:
#   Rewrites start() with a liveness check: PID file + kill -0 + comm == runsvdir.
#   WHY comm instead of the /proc/<pid>/exe path: after a package upgrade the
#   running manager still executes the replaced file ("runsvdir.dpkg-tmp (deleted)"),
#   so a path comparison gives a false negative and would create exactly the
#   duplicate this guard prevents.
#
# NOTE: $PREFIX/bin/service-daemon ships with the termux-services package and is
#   overwritten by "pkg upgrade". Re-run this script afterwards. The grep marker
#   below makes it safe to run repeatedly.

set -e
cd "$(dirname "$0")"

P="${PREFIX:-/data/data/com.termux/files/usr}"
TARGET="$P/bin/service-daemon"
# Short marker: matches the patched file AND the manually patched device copies.
MARK="WHY Liveness-Pruefung"

if [ ! -f "$TARGET" ]; then
    echo "termux-services-guard: $TARGET missing — is termux-services installed?" >&2
    exit 1
fi

if grep -q "$MARK" "$TARGET"; then
    echo "termux-services-guard: already active (nothing to do)"
    exit 0
fi

cp -a "$TARGET" "$TARGET.orig-$(date +%Y%m%d-%H%M%S)"

cat > "$TARGET" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh

set -e
start(){
    mkdir -p $PIDDIR
    # WHY Liveness-Pruefung (duplicate-runsvdir guard): profile.d/start-services.sh
    # calls "service-daemon start" on EVERY login shell. Without the check,
    # start-stop-daemon starts a second runsvdir each time; its runsv children die
    # on the supervise lock immediately and stay behind as zombies (8 per login).
    # WHY comm and not the exe path: while the manager still runs as the replaced
    # package file (runsvdir.dpkg-tmp, "(deleted)") a path comparison is a false
    # negative and would create the very duplicate this guard prevents.
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null && \
       [ "$(cat /proc/$pid/comm 2>/dev/null)" = "runsvdir" ]; then
        return 0
    fi
    start-stop-daemon -S -b -m -p $PIDFILE -x $DAEMON -d $PREFIX -- $DAEMON_OPTS
}
stop(){
    start-stop-daemon -K -s 1 -o -p $PIDFILE
    tail -f --pid=`cat $PIDFILE` /dev/null
    for f in $SVDIR/*/supervise $SVDIR/*/log/supervise;do
        kill -9 `cat $f/pid` 2>/dev/null ||:
        rm -rf $f
    done
}
# Must be a valid filename
NAME=service-daemon
PIDDIR=$PREFIX/var/run
PIDFILE=$PIDDIR/$NAME.pid
#This is the command to be run, give the full pathname
DAEMON=$PREFIX/bin/runsvdir
DAEMON_OPTS="$SVDIR"

case "$1" in
    start)
        echo -n "Starting daemon: "$NAME
        start
        echo "."
        ;;
    stop)
        echo -n "Stopping daemon: "$NAME
        stop
        echo "."
        ;;
    restart)
        echo -n "Restarting daemon: "$NAME
        stop
        start
        echo "."
        ;;

    *)
        echo "Usage: "$1" {start|stop|restart}"
        exit 1
esac

exit 0
EOF

chmod 700 "$TARGET"
sh -n "$TARGET"
echo "termux-services-guard: start() now checks the running manager (backup: $(basename "$TARGET").orig-*)"
