# KaleidashOS local identity

This layer applies the KaleidashOS identity to an existing Fedora installation without replacing Fedora packages, repositories, signing keys, or kernel infrastructure.

## Surfaces

- System metadata through a reversible `/etc/os-release` override
- `hostnamectl`, desktop system-information panels, and distro detection
- Desktop icon and an About KaleidashOS launcher entry
- Fastfetch with a graphical Kinetic K
- Automatic Fastfetch logo recoloring through a Noctalia v5 user template
- A dedicated high-contrast KaleidashOS control-center icon for the Noctalia panel
- Noctalia Greeter logo colored by the live wallpaper palette
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

After installation, reapply the current Noctalia theme or change the wallpaper once. Noctalia renders the full prismatic Kinetic K for Fastfetch and uses a separate bold monoline K for the panel. The panel glyph is colorized by Noctalia itself, so it always follows the same live widget color as the native panel icons.

The installer selects the Greeter's `Synced` scheme. Its wallpaper continues to come from Noctalia's normal Auto-Sync Greeter feature. The KaleidashOS logo and boot palette use Noctalia's user-template output directly, avoiding the extra delay before the Greeter sync file is updated.

Reboot when convenient to see GRUB, Plymouth, and the greeter branding.

Plymouth is stored in the initramfs, so it cannot consume live desktop files during boot. A systemd path unit now detects the palette file emitted during the same Noctalia theme application as the desktop logo. It updates the Greeter immediately and rebuilds Plymouth only when the palette digest has changed.

You can still force a manual refresh if needed:

```fish
./identity/sync-boot-theme.sh
```

This renders a 220 px K above the spinner, applies the current `surface`, `surface_variant`, `outline`, and `primary` colors, and forces one initramfs rebuild.

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
