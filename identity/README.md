# KaleidashOS local identity

This layer applies the KaleidashOS identity to an existing Fedora installation without replacing Fedora packages, repositories, signing keys, or kernel infrastructure.

## Surfaces

- Display metadata through a reversible, Fedora-compatible `/etc/os-release` overlay
- `hostnamectl`, desktop system-information panels, and distro detection
- Desktop icon and an About KaleidashOS launcher entry
- Fastfetch with a graphical Kinetic K
- Automatic Fastfetch logo recoloring through a Noctalia v5 user template
- A dedicated high-contrast KaleidashOS control-center icon for the Noctalia panel
- Noctalia Greeter logo colored by the live wallpaper palette
- KaleidashOS GRUB theme
- KaleidashOS Plymouth boot splash based on Fedora's password-capable spinner theme
- TTY and remote-login identification

KaleidashOS is represented as a presentation layer over the installed Fedora edition. `NAME`, `PRETTY_NAME`, `VARIANT`, `LOGO`, and project URLs are branded, while Fedora's machine-readable `ID`, `ID_LIKE`, `VERSION_ID`, `VARIANT_ID`, CPE, support-product, and release fields are preserved verbatim. DNF, COPR, release upgrades, and third-party installers therefore continue to detect the system as Fedora.

## Install

Run as the normal desktop user from a repository checkout:

```fish
./identity/install.sh
```

The installer requests `sudo` for system-owned files. It installs `plymouth-theme-spinner` and `librsvg2-tools`, creates backups under `/var/lib/kaleidash-os`, and stores user-config backups under `~/.local/state/kaleidash-os`.

After installation, reapply the current Noctalia theme or change the wallpaper once. Noctalia renders the full prismatic Kinetic K for Fastfetch and uses a separate bold monoline K for the panel. The panel glyph is colorized by Noctalia itself, so it always follows the same live widget color as the native panel icons.

The primary and compact SVGs under `brand/logo/` are the geometry sources for system branding and Fastfetch respectively. During every installation, KaleidashOS regenerates the Noctalia-aware templates from those files. Updating the official SVG artwork therefore updates Fastfetch, Plymouth, and the Greeter without maintaining a second copy of the paths.

The installer selects the Greeter's `Synced` scheme. Its wallpaper continues to come from Noctalia's normal Auto-Sync Greeter feature. The KaleidashOS logo and boot palette use Noctalia's user-template output directly, avoiding the extra delay before the Greeter sync file is updated.

Reboot when convenient to see GRUB, Plymouth, and the greeter branding.

Plymouth is stored in the initramfs, so it cannot consume live desktop files during boot. A systemd path unit now detects the palette file emitted during the same Noctalia theme application as the desktop logo. It updates the Greeter immediately and rebuilds Plymouth only when the palette digest has changed.

You can still force a manual refresh if needed:

```fish
./identity/sync-boot-theme.sh
```

This renders a 220 px K above the spinner, applies the current `surface`, `surface_variant`, `outline`, and `primary` colors, and forces one initramfs rebuild.

The installer makes the GRUB menu visible for two seconds so the identity is actually shown. Uninstalling restores the original GRUB defaults and `grubenv`, including Fedora's previous auto-hide behavior.

The GRUB entry intentionally appears as `KaleidashOS` because the installer sets `GRUB_DISTRIBUTOR` to the branded name. The underlying Fedora release and variant remain recorded from `/usr/lib/os-release` by the inventory collector.

The installer enables `kaleidash-os-release-sync.service` and its path watcher. They regenerate the branded overlay from Fedora's authoritative `/usr/lib/os-release` at every boot and whenever that vendor file changes. After a Fedora major-version upgrade, KaleidashOS therefore adopts the new Fedora version automatically without pinning DNF or COPR to the previous release.

## Restore Fedora branding

Run as the same desktop user:

```fish
./identity/uninstall.sh
```

The restore script reinstates the original files and symlinks, regenerates GRUB and the initramfs, and restores the Plymouth theme that was active before installation.

## Compatibility boundary

The identity layer deliberately does not alter:

- Fedora DNF repositories
- Fedora package resolution or COPR detection
- RPM macros or package provenance
- Fedora signing keys
- kernel package names
- Secure Boot configuration
- the Plasma fallback session

The vendor release data remains authoritative at `/usr/lib/os-release`. The generated `/etc/os-release` changes display-oriented fields only and is refreshed automatically from the vendor file. Uninstalling restores the exact original file or symlink.
