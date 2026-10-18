# Termux Basic Packages

Fresh-rooted-phone-ready installer for Termux: packages, custom bash banner, and a
**three-layer SSH/ADB autostart** architecture that survives Android's aggressive
process killing (phantom process killer, cached-apps freezer, Doze).

> Validated live on a Note10+ with KernelSU (Oct 2026) — see "Architecture".
> No private keys are ever stored in this repo.

## Quick Installation termux packages

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xMugi/Termux-package/master/termux-package.sh)"
```

## Quick Installation Termux Metasploit
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xMugi/Termux-package/master/termux-metasploit.sh)"
```

To (re)customize your bash only:
```bash
cd ~/Termux-package && chmod +x ./termux-bashsetup.sh && ./termux-bashsetup.sh
```

# Architecture (why it does not die)

| Layer | Path | What | Needs |
|---|---|---|---|
| **L1 primary** | `/data/adb/service.d/00-termux-boot.sh` | adbd on TCP 7777 (RustDesk), phantom-killer + freezer off (Android 12-16 keys), Doze whitelist, Termux wake-lock + sshd via RunCommandService | root (KernelSU/Magisk) |
| **L2 fallback** | `~/.termux/boot/{sshd,adb}` | sshd + wireless ADB when root path is absent | Termux:Boot app opened once |
| **L3 requirement** | `~/.termux/termux.properties` | `allow-external-apps = true` — termux blocks external RunCommand intents otherwise | — |

Why root-side primary: `setprop service.adb.*` and battery/killer hardening are
root-only operations — Termux-UID scripts (Termux:Boot) can never do them.

## Fresh rooted phone — manual follow-ups (after the quick-install)

1. **Termux:Boot app**: install + open it ONCE (Android sends `BOOT_COMPLETED`
   never to "stopped" apps).
2. **SSH keys** (from your PC, PowerShell):
   ```powershell
   # set a temp password in termux first: passwd
   ssh-keygen -y -f $env:USERPROFILE\.ssh\mykey |
       ssh -p 8022 u0_xxx@<phone-ip> "tee -a ~/.ssh/authorized_keys >/dev/null"
   ```
3. **Reboot once** — `cached_apps_freezer` only takes effect on a boot.
4. **Verify**:
   ```bash
   pidof sshd                      # two PIDs: root sshd + termux sshd
   ssh -p 8022 user@<phone-ip>     # termux shell via its own sshd
   netstat -tln | grep 7777        # wireless ADB ready for RustDesk
   ```

## bash double-load fix

Termux sources `$PREFIX/etc/bash.bashrc` for *every* interactive shell and
`$HOME/.bashrc` for login shells. The old installer created `~/.bashrc` as a
symlink to the same file → banner/clear/neofetch rendered twice per session.
The installer now keeps custom content only in `$PREFIX/etc/bash.bashrc`
(diverted against `pkg upgrade`), removes any `~/.bashrc`, and ships
`~/.config/neofetch/config.conf`.

## Files

| File | Purpose |
|---|---|
| `termux-package.sh` | One-shot entry point (curl quick-install) |
| `termux-bashsetup.sh` | bash.bashrc + neofetch, single-load, upgrade-safe |
| `termux-autoruns.sh` | L1-L3 wiring, idempotent |
| `root-boot/00-termux-boot.sh` | Root boot script (deployed to `/data/adb/service.d/`) — device-agnostic, Android 12-16 |
| `sshd`, `adb` | Termux:Boot fallback scripts (`~/.termux/boot/`) |
| `bash.bashrc`, `neofetch.conf` | Shell look + fetch theme |
| `termux-metasploit.sh` | Metasploit setup (separate) |

# Addons
- [docker-qemu-arm](https://github.com/xMugi/docker-qemu-arm) - Docker on Android via Termux and Qemu-ARM VM
- [termux-hacking-tools](https://github.com/xMugi/termux-hacks-collection) - Collection of hacking tools for Termux (Alternate Link)
