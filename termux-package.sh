#!/data/data/com.termux/files/usr/bin/bash
# Termux-package master installer (xMugi/Termux-package)
# Standalone entry point:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/xMugi/Termux-package/master/termux-package.sh)"
#
# Flow (fresh rooted phone, ~5 min):
#   [1/6] termux-setup-storage          → storage access prompt (one-time)
#   [2/6] pkg packages (incl. openssh)  → toolchain
#   [3/6] git clone/refresh this repo   → ~/Termux-package
#   [4/6] termux-bashsetup.sh           → bash.bashrc WITHOUT the old double-load symlink
#   [5/6] termux-autoruns.sh            → allow-external-apps + Termux:Boot fallback + root service.d
#   [6/6] termux-apps.sh                → only with --apps: RustDesk + Tailscale APKs (root)

set -e
REPO_URL=https://github.com/xMugi/Termux-package.git
REPO_DIR="$HOME/Termux-package"
APPS=0
[ "${1:-}" = "--apps" ] && APPS=1

echo "[1/6] storage access"
termux-setup-storage 2>/dev/null || true

echo "[2/6] packages (this can take a few minutes)"
pkg update -y
pkg install -y tur-repo root-repo x11-repo
pkg update -y
pkg upgrade -y
pkg install -y neofetch python python-psutil termux-services termux-tools tmux android-tools \
    nodejs-lts git perl bash nano ruby build-essential ffmpeg curl openssl openssh wget clang \
    nmap w3m coreutils fish zip figlet cowsay unzip wcalc bmon unrar golang termux-api \
    dnsutils rclone command-not-found tsu cronie

echo "[3/6] fetch repo"
if [ -d "$REPO_DIR/.git" ]; then
    (cd "$REPO_DIR" && git pull --ff-only) || true
else
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

echo "[4/6] bash setup (banner/neofetch, single-load)"
chmod +x ./termux-bashsetup.sh
./termux-bashsetup.sh

echo "[5/6] autoruns (termux.properties, Termux:Boot fallback, root service.d)"
chmod +x ./termux-autoruns.sh
./termux-autoruns.sh

if [ "$APPS" = 1 ]; then
    echo "[6/6] Android apps: RustDesk + Tailscale (root)"
    chmod +x ./termux-apps.sh
    ./termux-apps.sh || echo "apps step failed — re-run ./termux-apps.sh manually" >&2
else
    echo "[6/6] skipped: RustDesk + Tailscale APKs — run ./termux-apps.sh, or re-run"
    echo "      this installer as 'bash termux-package.sh --apps' to include them."
fi

cat <<'EOF'

=== Done. Manual follow-ups ===
1) Install the Termux:Boot app (F-Droid/GitHub) and open it ONCE.
   WHY: Android flags freshly installed apps as "stopped" and never sends
   BOOT_COMPLETED — without that one launch the boot fallback never fires.
2) Set up SSH key auth (one-time, from your PC):
      passwd                # in Termux, set a temporary password
      # from PC (PowerShell):
      ssh-keygen -y -f $env:USERPROFILE\.ssh\<key> |
        ssh -p 8022 u0_xxx@<phone-ip> "tee -a ~/.ssh/authorized_keys >/dev/null"
3) Reboot the phone, then verify:
      pidof sshd            # two PIDs: root sshd + termux sshd
      ssh -p 8022 <user>@<phone-ip>

No private keys are ever stored in this repo.
EOF
