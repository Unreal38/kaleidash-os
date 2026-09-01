# KaleidashOS local identity

This layer applies the KaleidashOS identity to an existing Fedora installation without replacing Fedora packages, repositories, signing keys, or kernel infrastructure.

## Surfaces

- System metadata through a reversible `/etc/os-release` override
- `hostnamectl`, desktop system-information panels, and distro detection
- Desktop icon and an About KaleidashOS launcher entry
- Fastfetch with a graphical Kinetic K
- Automatic Fastfetch logo recoloring through a Noctalia v5 user template
- Noctalia control-center icon and Greeter logo colored by the synchronized palette
- KaleidashOS GRUB theme
- KaleidashOS Plymouth boot splash based on Fedora's password-capable spinner theme
- TTY and remote-login identification

Fedora compatibility is advertised through `ID_LIKE=fedora`. Some third-party installation scripts check only `ID=fedora`; use their Fedora instructions manually if they reject `ID=kaleidash`.

## Install

Run as the normal desktop user from a repository checkout:

```fish
./identity/install.sh
```

The installer requests `sudo` for system-owned files. It installs `plymouth-theme-spinner` and `librsvg2-tools`, creates backups under `/var/lib/kaleidash-os`, and stores user-config backups under `~/.local/state/kaleidash-os`.

After installation, reapply the current Noctalia theme or change the wallpaper once. Noctalia will render the Kinetic K using the current `primary`, `secondary`, and `tertiary` colors. The control-center button uses that same live SVG.

The installer selects the Greeter's `Synced` scheme. Its wallpaper and palette continue to come from Noctalia's normal Auto-Sync Greeter feature. A systemd path unit rebuilds the Greeter K whenever `/var/lib/noctalia-greeter/sync.toml` changes.

Reboot when convenient to see GRUB, Plymouth, and the greeter branding.

Plymouth is stored in the initramfs, so it cannot consume live desktop files during boot. The installer snapshots the current Noctalia logo and Greeter palette. After changing wallpaper later, update the next boot splash explicitly:

```fish
./identity/sync-boot-theme.sh
```

This renders a 220 px K above the spinner, applies the current `surface`, `surface_variant`, `outline`, and `primary` colors, and rebuilds the initramfs once.

The installer makes the GRUB menu visible for two seconds so the identity is actually shown. Uninstalling restores the original GRUB defaults and `grubenv`, including Fedora's previous auto-hide behavior.

After a Fedora major-version upgrade, rerun `./identity/install.sh` so the KaleidashOS version fields are refreshed from Fedora's new `/usr/lib/os-release`.

## Restore Fedora branding

Run as the same desktop user:

```fish
./identity/uninstall.sh
```

The restore script reinstates the original files and symlinks, regenerates GRUB and the initramfs, and restores the Plymouth theme that was active before installation.

## Compatibility boundary

The identity layer deliberately does not alter:

- Fedora DNF repositories
- RPM macros or package provenance
- Fedora signing keys
- kernel package names
- Secure Boot configuration
- the Plasma fallback session

The vendor release data remains available at `/usr/lib/os-release`. The KaleidashOS identity lives in `/etc/os-release`, which is the administrator override location defined by the `os-release` specification.
