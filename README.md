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

## Quick Installation Android apps (RustDesk + Tailscale)
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xMugi/Termux-package/master/termux-apps.sh)"
```
Needs root. Installs/updates both APKs and applies the Android-side grants so they
survive a reboot without dialogs. Login and passwords stay manual (see below).

To (re)customize your bash only:
```bash
cd ~/Termux-package && chmod +x ./termux-bashsetup.sh && ./termux-bashsetup.sh
```

# Architecture (why it does not die)

| Layer | Path | What | Needs |
|---|---|---|---|
| **L1 primary** | `/data/adb/service.d/00-termux-boot.sh` + `20-noautoapps.sh` + `30-apps.sh` | adbd on TCP 7777 (RustDesk), phantom-killer + freezer off (Android 12-16 keys), Doze whitelist, Termux wake-lock + sshd via RunCommandService; boot guard force-stops apps that come back on their own; `30-apps.sh` re-asserts the RustDesk/Tailscale app-ops, Doze entries and RustDesk's accessibility entry (input control) | root (KernelSU/Magisk) |
| **L2 fallback** | `~/.termux/boot/{sshd,adb,termuxservices}` | sshd + wireless ADB + service manager when root path is absent | Termux:Boot app opened once |
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

## Autostart: what comes up after a reboot

Android has no init for apps, so there is no unit file — three layers plus a set of
app-side grants cover it:

| What | Started by | Check after a reboot |
|---|---|---|
| root sshd (uid 0) + adbd on 7777 | `/data/adb/service.d/00-termux-boot.sh` (L1, root) | `pidof sshd`, `netstat -tln \| grep 7777` |
| Termux sshd on 8022 | L1 via RunCommandService, fallback `~/.termux/boot/sshd` (L2) | `ssh -p 8022 …`, `sv status $PREFIX/var/service/sshd` |
| Termux services (`crond`, `komodo`, …) | `runsvdir`, started by a login shell or L2 `termuxservices` | `sv status $PREFIX/var/service/*` |
| Komodo Periphery | runsv service `komodo` + boot entry `~/.termux/boot/90-komodo` | `sv status $PREFIX/var/service/komodo`, `tail -5 ~/.local/state/komodo/log/current` |
| RustDesk/Tailscale grants | `/data/adb/service.d/30-apps.sh` (L1, root) | `bash termux-apps.sh verify` |
| RustDesk app + screen capture | the app's own "start on boot" flag (set once in the app) | `bash termux-apps.sh verify` → `capture session` / `virtual display` |
| Tailscale VPN | the app's own boot receiver | `su -c "ip -4 -o addr show tun0"` |

Service control (runsv instead of systemd): services live in `$PREFIX/var/service/<name>`
and are handled with `sv status|up|down|restart <name>`. A file named `down` inside the
service directory disables the autostart — that is how unused services stay off after a
reboot, even if something calls `sv up`. Logs: `$PREFIX/var/log/sv/<name>/current`.

Honest status: L1 and L2 are reboot-verified on two devices (Note10P/KernelSU, Pixel
8/Magisk). `30-apps.sh` is deployed and dry-run on both, but **the reboot test that
proves it is still open**.

## Komodo Periphery (optional)

`komodo/` installs the Periphery agent that connects a phone to a Komodo Core
(container/stack dashboard). Full setup, Core-side steps and troubleshooting:
[`komodo/README.md`](komodo/README.md).

```bash
bash komodo/install.sh                       # install + register the runsv service
bash komodo/install.sh --version vX.Y.Z      # update the binary only (config/keys stay)
sv status $PREFIX/var/service/komodo         # run/restart state
tail -f ~/.local/state/komodo/log/current    # agent log ("Logged in … as Server …")
```

Autostart is two-part: the runsv service (restarts the agent, survives Termux restarts)
and the boot entry `~/.termux/boot/90-komodo` (brings `runsvdir` up after a reboot).

WHY this matters when renaming: `connect_as` in `periphery.config.toml` must hold the
**Server ID**, never the name. An existing connection hides the stale name; after a Core
restart the agent can no longer connect ("Server … is not connected", every stack shows
`unknown`). With the ID, renaming the Server in Komodo needs no agent change.

## On-demand apps and the service-manager guard (2026-10-18)

Both come from a measured Pixel 8 (Android 16, Magisk) with `adb`/root and are
opt-in by nature — nothing here is required for SSH/ADB to work.

- **`root-boot/20-noautoapps.sh`** (L1) force-stops apps 90 s after boot unless they
  are in the foreground at that moment. Measured win: Firefox ~1 GB RSS, Play Store
  3 processes ~525 MB RSS, Calendar 45 MB PSS, Contacts `learning_bg` 42 MB PSS,
  MMRL 30 MB PSS — together ~1.43 GB RSS and 2:32 CPU time (Play Store background)
  that are simply not needed resident. Pair it with
  `cmd appops set --user 0 <pkg> RUN_ANY_IN_BACKGROUND ignore` so the apps also stay
  away between boots; foreground use is unaffected (verified: Play Store launches).
  Revert: `rm /data/adb/service.d/20-noautoapps.sh` and
  `cmd appops set --user 0 <pkg> RUN_ANY_IN_BACKGROUND default`.
- **`termux-services-guard.sh`** patches `$PREFIX/bin/service-daemon` with a
  liveness check. Without it, every login shell (profile.d/start-services.sh) starts
  a second `runsvdir`; its `runsv` children lose the supervise lock, exit instantly
  and remain as zombies — 8 per login measured. It is idempotent (grep marker) and
  keeps a timestamped backup of the package file; re-run it after `pkg upgrade`.
- **`termuxservices`** (L2) deliberately does **not** call `sv up sshd`: sshd belongs
  to L1. The runsv sshd service has a `down` file, but `sv up` started it anyway and
  it fought the L1 listener for port 8022 (bind loop in the sv log). A stale backup
  inside `~/.termux/boot/` recreates that bug, which is why this installer keeps its
  backup in `~/.termux-boot-backup/` instead.

## Apps: RustDesk + Tailscale (2026-10-18)

Both are GUI apps; neither runs inside Termux. So they are installed as **APKs** and
`termux-apps.sh` only scripts what Android needs around them (download, install,
app-ops, Doze whitelist, accessibility, a start-on-boot flag).

```bash
bash termux-apps.sh                # both, install/update + all grants
bash termux-apps.sh verify         # read-only state check
bash termux-apps.sh rustdesk       # one app only
bash termux-apps.sh --no-install   # grants only, no download
bash termux-apps.sh anydesk-off    # switch away from AnyDesk (disable + drop its grants)
bash termux-apps.sh anydesk-restore # enable AnyDesk again
bash termux-apps.sh rustdesk-restart # client stuck at "waiting for image"
```

| Step | Automatic | Why / how |
|---|---|---|
| RustDesk APK (arm64/armv7/x86_64) | yes | GitHub release `rustdesk-<version>-<arch>-signed.apk`; version resolved via the GitHub API, fallback `1.5.0` |
| Tailscale APK (universal) | yes | release asset from `github.com/tailscale/tailscale-android` (100.6 MB), sha256 taken from the GitHub API `digest`; a pinned `TAILSCALE_VERSION` is matched against the asset names |
| Install as root | yes | APK copied to `/data/local/tmp` (avoids Termux SELinux friction), `pm install -r -d` |
| RustDesk screen capture | yes | `appops set com.carriez.flutter_hbb PROJECT_MEDIA allow` — removes the per-session **"Start recording or casting with RustDesk?"** dialog (measured on Note10P/Android 15: before `ignore`, after `allow` the projection comes up unattended) |
| RustDesk input control | yes | RustDesk's `.InputService` **is** an AccessibilityService; it is *appended* to `enabled_accessibility_services` so AnyDesk keeps its own entry (`anydesk-off` removes exactly the AnyDesk entries) |
| RustDesk start-on-boot | yes | flag in the app's `KEY_START_ON_BOOT_OPT` pref, set with the app stopped; if the key is missing the script only prints a hint |
| Tailscale VPN consent | yes | `appops set com.tailscale.ipn ACTIVATE_VPN allow` — without it Android asks on every connection attempt |
| Both: Doze whitelist + background | yes | `dumpsys deviceidle whitelist +<pkg>` and `RUN_IN_BACKGROUND allow` |
| Tailscale login | **no** | interactive: browser login or auth key in the app |
| RustDesk password/PIN | **no** | set in the app; nothing secret is stored by this repo |
| Updates | yes | the APK updates an existing installation in place (same signing key, app data untouched); only an installation signed with a *different* key needs `--replace` |
| Switch away from AnyDesk | yes | `termux-apps.sh anydesk-off`: force-stop, `pm disable-user` (reversible; `--uninstall` removes instead), AnyDesk entries out of `enabled_accessibility_services`, Doze entry off, `PROJECT_MEDIA`/`SYSTEM_ALERT_WINDOW`/background app-ops back to `default`. Handles both known packages (`com.anydesk.anydeskandroid`, `com.anydesk.adcontrol.ad1`) and skips what is not installed |

`root-boot/30-apps.sh` re-asserts both app-ops after every boot and is deployed by
`termux-autoruns.sh` (step [5/6]) like the other root boot scripts. App-ops persist
across reboots by themselves (verified on the Note10P: `PROJECT_MEDIA allow` and
`ACTIVATE_VPN allow` survived a reboot and were used ~1 min after boot), but a ROM
update or Android's "reset app preferences" clears them — and then RustDesk shows the
consent dialog again.

Notes from the live test (Note10P, Android 15, 2026-10-18):

- The script **starts RustDesk once** at the end. Reason: the "start on boot"
  preference can only be written while the app is stopped, and Android drops the
  accessibility entry of a *stopped* package — starting it again is what makes the
  entry stick.
- Tailscale is taken from **GitHub** (`github.com/tailscale/tailscale-android`), which
  is the only source the script uses: same Tailscale-signed APK, no account, and the
  GitHub API already carries the sha256 digest. Verified: the `1.104.1` asset
  (100.6 MB) downloads and its hash matches.
- A store installation **is** replaced in place: the published APK carries the same
  signing key, so `pm install -r` updates it and app data stays untouched. Verified on
  the Note10P (2026-10-18): after the swap the installer field changed from the store
  package manager to `null`, the tailnet address stayed up and the login survived.
  `--replace` remains the fallback for an installation signed with a *different* key.
- After an **app update** Android may drop the accessibility entry again (A14+ policy).
  `termux-apps.sh verify` shows this as `accessibility (dumpsys): RustDesk NOT enabled`;
  re-running the script fixes it.
- The APK install path was tested with `--reinstall` on the Note10P:
  `rustdesk-1.5.0-aarch64-signed.apk` (27.4 MB) → `pm install -r` → version 1.5.0,
  existing data untouched.

Security note: `PROJECT_MEDIA allow` means RustDesk may capture the screen without
any system prompt. Android still shows the screen-sharing indicator, which can stop
the capture at any time. Revert with
`su -c "cmd appops set com.carriez.flutter_hbb PROJECT_MEDIA default"`.

### Switching away from AnyDesk

Installing RustDesk is only half of the swap: AnyDesk keeps running, keeps its
accessibility service (remote input), its Doze entry and — if it was ever used
unattended — `PROJECT_MEDIA allow`, which is the same consent-dialog bypass. So the
order matters:

1. `bash termux-apps.sh rustdesk` — install RustDesk and its grants.
2. Connect once from the client and confirm the phone answers; only then remove
   AnyDesk. Removing it first can cut the remote path to that device.
3. `bash termux-apps.sh anydesk-off` — reversible (`pm disable-user`, app data kept).
   `--uninstall` removes the packages, `anydesk-restore` enables them again.

### Client stuck at "waiting for image"

Measured on the Pixel 8 (Android 16, 2026-10-18), after scrcpy had been running
alongside RustDesk:

- `dumpsys media_projection` still shows an **active session** for RustDesk while
  `dumpsys display` shows its virtual display `RustDeskVD` as **OFF** (or gone
  entirely) — a session without frames.
- Reason: with `PROJECT_MEDIA allow` Android no longer *stops* an existing projection,
  it *continues* it (`MediaProjectionStopController: Continuing MediaProjection for
  package with OP_PROJECT_MEDIA AppOp`). When RustDesk's capture service dies — client
  disconnect, screen lock, a second capture tool like scrcpy — the app therefore never
  gets the stop callback, keeps a dead session and never requests a new projection.
  The client then waits forever.
- Fix: `bash termux-apps.sh rustdesk-restart` (force-stop + start). RustDesk asks for a
  fresh projection, and the app-op still skips the consent dialog. Verified: display
  state changes from OFF to ON, image is back.
- The same command **re-asserts the accessibility entry**, because `am force-stop`
  drops it: without that step the image returns but input stays dead — RustDesk shows
  "Input control" disabled and the dialog "How to get Android input permission?"
  (measured on the Pixel 8, 2026-10-18). The command prints both states, so a wrong
  result is visible instead of silent.
- `bash termux-apps.sh verify` now separates both states:
  `capture session: present / virtual display: OFF` is the stuck/idle signature,
  `ON` means frames are flowing.

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
| `termux-autoruns.sh` | L1-L3 wiring, idempotent (also installs both guards below) |
| `root-boot/00-termux-boot.sh` | Root boot script (deployed to `/data/adb/service.d/`) — device-agnostic, Android 12-16 |
| `root-boot/20-noautoapps.sh` | Root boot guard: force-stops apps that autostart unasked (list editable) |
| `termux-apps.sh` | RustDesk + Tailscale APK install/update and the Android-side grants (root) |
| `root-boot/30-apps.sh` | Root boot script: re-asserts the RustDesk/Tailscale app-ops, Doze entries and RustDesk's accessibility entry (input control) |
| `termuxservices` | Termux:Boot L2 script (wake-lock, `sv up crond`, sshd fallback, tmux) |
| `termux-services-guard.sh` | Liveness check for termux-services' `service-daemon` (no duplicate runsvdir) |
| `sshd`, `adb` | Termux:Boot fallback scripts (`~/.termux/boot/`) |
| `bash.bashrc`, `neofetch.conf` | Shell look + fetch theme |
| `termux-metasploit.sh` | Metasploit setup (separate) |
| `komodo/` | Komodo Periphery on Termux: `install.sh` (idempotent, `--version` for updates), `boot/komodo` + `service/*` (runsv + boot entry), own `README.md` with setup and troubleshooting |
| `modules/SSH for Magisk-v0.27.zip` | Bundled Magisk module (SSH for Magisk v0.27) for manual install on a device without root SSH — no script in this repo references it |
| `LICENSE` | GPL-3.0 |

## Troubleshooting quick list

| Symptom | First move |
|---|---|
| SSH/ADB gone after a reboot | `pidof sshd`, `netstat -tln \| grep 7777`, `sv status $PREFIX/var/service/*`, then check the scripts in `/data/adb/service.d/` |
| Eight zombies, duplicate `runsvdir` per login | `bash termux-services-guard.sh` — re-run it after every `pkg upgrade` |
| RustDesk shows the image but no input | `bash termux-apps.sh verify` (accessibility line), then `bash termux-apps.sh rustdesk-restart` — `force-stop` drops the entry, the command re-asserts it |
| RustDesk client stuck at "waiting for image" | `bash termux-apps.sh rustdesk-restart` (session present, virtual display OFF) |
| RustDesk consent dialog is back | `bash termux-apps.sh --no-install` (sets `PROJECT_MEDIA allow` again) |
| Tailscale asks for VPN consent on every connect | `bash termux-apps.sh tailscale` |
| AnyDesk still usable after the swap | `bash termux-apps.sh anydesk-off` |
| Komodo: server `NotOk`, all stacks `unknown` | `tail -20 ~/.local/state/komodo/log/current`; `connect_as` must be the Server ID; then `sv restart $PREFIX/var/service/komodo` |

# Addons
- [docker-qemu-arm](https://github.com/xMugi/docker-qemu-arm) - Docker on Android via Termux and Qemu-ARM VM
- [termux-hacking-tools](https://github.com/xMugi/termux-hacks-collection) - Collection of hacking tools for Termux (Alternate Link)
