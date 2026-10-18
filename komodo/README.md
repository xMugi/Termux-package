# Komodo Periphery on Android / Termux

Runs the official Komodo **Periphery v2** agent natively under Termux, so a phone
shows up as its own server in the Komodo instance on Unraid. No proot, no Linux
distribution, no Docker.

Validated on a Note 10+ (Android 15, KernelSU); prepared for other ARM64 devices
(Pixel 8, Android 16, Magisk).

## Why glibc-runner

`periphery-aarch64` is a GNU/Linux build and expects `/lib/ld-linux-aarch64.so.1`.
Android uses bionic, so calling it directly fails with
`cannot execute: required file not found`. Termux's `glibc-runner` supplies the
loader and the binary runs unchanged.

## Layout

| Path | Purpose |
|---|---|
| `~/.config/komodo/periphery.config.toml` | config (0600) |
| `~/.local/share/komodo/bin/periphery-<v>` | binary, plus `periphery` symlink for switching |
| `~/.local/share/komodo/data/` | `root_directory`: `keys/` (server identity), stacks, repos |
| `~/.local/state/komodo/log/current` | agent log, rotated by svlogd |
| `$PREFIX/var/service/komodo/` | runsv service (auto-restart, `sv` control) |
| `~/.termux/boot/90-komodo` | Termux:Boot autostart |

## Install / update

```bash
cd ~/Termux-package/komodo

# new device — key from Komodo: Servers -> New Server -> create with "privileged"
bash install.sh --connect-as PIXEL8 --core ws://unraid:9120 --onboarding-key -

# reinstall or repair (existing config and keys are kept)
bash install.sh

# update the agent (only the binary changes, then the service restarts)
bash install.sh --version v2.3.4
```

The onboarding key is only needed for the first login. Afterwards the stored private
key authenticates via the Noise handshake — remove the `onboarding_key` line and run
`sv down|up $PREFIX/var/service/komodo`.

## Control

```bash
sv status  $PREFIX/var/service/komodo     # run/down + pid
sv down    $PREFIX/var/service/komodo     # stop (stays down)
sv up      $PREFIX/var/service/komodo     # start (auto-restart on crash)
tail -f ~/.local/state/komodo/log/current # log
sv status $PREFIX/var/service/komodo/log  # log service
```

No helper script, no PID file, no cron: runsv supervises, svlogd rotates, and the
Termux:Boot entry only has to turn the service on.

## Known limits on Android

- **No Docker** — the CLI exists, the daemon does not. Container/stacks views stay
  empty and every docker call fails with `Cannot connect to the Docker daemon`.
  The Periphery config has **no `disable_docker` switch**; available are
  `disable_container_terminals = true` and `container_stats_polling_rate = "30-day"`.
- **Disk numbers are approximations.** Android exposes many virtual mounts; the config
  limits the report to `include_disk_mounts = ["/", "/storage/emulated"]`. Never sum
  values across mounts — several paths can show the same partition.
- **Not a bionic build** — it is the GNU/Linux binary on top of glibc-runner. Re-check
  after Termux or Android upgrades.
- **Outbound only** (`server_enabled = false`): nothing listens on the phone.
- **Terminal runs as the Termux user** (`u0_aXXX`); root only through `su`.
- Untested: reboot/autostart end-to-end, behaviour under memory pressure, Termux
  upgrades replacing `glibc-runner`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `duplicate key` then `Read-only file system (30)` | a TOML key appears twice → Periphery discards the whole config and uses `/etc/komodo` | `python -c "import tomllib;tomllib.load(open('<conf>','rb'))"`, remove the duplicate |
| `cannot execute: required file not found` | started without the glibc loader | start through `grun` (the run script does) |
| Terminal fails: `Child process exited immediately with code 1` | Periphery shlex-splits `default_terminal_command` and spawns it as a program, so a shell *command* passed as the init command cannot work | keep `bash` (or `sh`) as the init command; run commands *inside* the opened terminal |
| No start after reboot | Termux:Boot never opened, or no runsvdir | open Termux:Boot once; check `~/.local/state/komodo/boot.log` |
| Agent confusing in Komodo | server disabled in Core, or key mismatch | compare `Public Key:` in the log with the server entry in Core |

## Security

- Periphery runs as the normal Termux user, never permanently as root.
- One private key per device — never copy keys between phones.
- Treat any onboarding key that appeared in a log or chat as compromised: delete it in
  Komodo and onboard again.
- The Komodo UI reaches into the phone through a terminal; keep Tailscale/LAN access
  controlled and never expose Periphery publicly.
