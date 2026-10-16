#!/data/data/com.termux/files/usr/bin/bash
# Installs the custom bash config + neofetch theme.
#
# WHY this shape (learned on the Note10P):
# Termux sources $PREFIX/etc/bash.bashrc for EVERY interactive shell:
#   - login shells:  via $PREFIX/etc/profile
#   - non-login:     directly (bash patched with TERMUX prefix sys-bashrc)
# The old setup ALSO created ~/.bashrc as a symlink to the same file, so
# $PREFIX/etc/profile sourced it a second time for login shells
# => banner + clear + neofetch rendered twice, "double refresh" on new sessions.
# Therefore: custom content lives ONLY in $PREFIX/etc/bash.bashrc. NO ~/.bashrc.

set -e
cd "$(dirname "$0")"
BBC="$PREFIX/etc/bash.bashrc"

if grep -q "termux.dev/docs" "$BBC" 2>/dev/null; then
    echo "bash.bashrc: already installed — skipping"
else
    # dpkg-divert moves the package-owned stock file aside permanently, so a
    # later "pkg upgrade bash" cannot clobber the custom file (it variants
    # upgrades into $BBC.stock instead). Fallback: plain backup file.
    if command -v dpkg-divert >/dev/null 2>&1; then
        dpkg-divert --add --rename --divert "$BBC.stock" "$BBC" >/dev/null 2>&1 \
            || cp -f "$BBC" "${BBC}.backup" 2>/dev/null || true
    else
        cp -f "$BBC" "${BBC}.backup" 2>/dev/null || true
    fi
    cp -f ./bash.bashrc "$BBC"
    echo "bash.bashrc installed (stock saved as $BBC.stock|.backup)"
fi

# Kill the double-load symlink → idempotent, no-ops when it does not exist.
rm -f "$HOME/.bashrc"

mkdir -p "$HOME/.config/neofetch" && cp -f ./neofetch.conf "$HOME/.config/neofetch/config.conf"
echo "neofetch.conf installed"
