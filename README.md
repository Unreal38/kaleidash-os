# KaleidashOS

**Every wallpaper, a new desktop.**

KaleidashOS is a reproducible Fedora desktop profile built around Niri and Noctalia. Its goal is to combine fast, responsive window switching with cohesive styling that adapts essential applications to the current wallpaper.

This repository is in its initial identity and inventory phase. It will grow into a repeatable setup for recreating the same desktop on another Fedora device without pretending to be an independent Linux distribution at the package-management level.

## Principles

- Fast and predictable keyboard-driven window movement
- Wallpaper-derived colors across the shell and essential applications
- A cohesive desktop that feels fresh after every wallpaper change
- Reproducible installation instead of an opaque disk image
- Fedora remains the underlying operating-system identity

## Current contents

- `brand/` - KaleidashOS identity and vector logo assets
- `bootstrap/` and `bootstrap.sh` - safe manifest-driven installation planning and application
- `config/` - privacy-conscious configuration capture and reversible portable desktop bundles
- `fastfetch/` - example Fastfetch identity and graphical-logo configuration
- `identity/` - reversible local branding for metadata, desktop, terminal, greeter, GRUB, and Plymouth
- `inventory/` - privacy-conscious capture of packages, repositories, services, and component versions
- `manifests/` - reviewed portable base and opt-in software/hardware profiles
- `requirements/` - authoritative default applications, settings, configuration, and privacy scope

## Planned structure

- Niri and Noctalia configuration
- Terminal, Yazi, GTK, Qt, KDE, and Firefox theming
- Wallpaper-palette propagation
- Installation and update scripts
- Hardware-specific features isolated as optional profiles

## Status

Early development. Identity, inventory capture, the first manifest-driven bootstrap installer, the wallpaper-reactive lock-screen bundle, and portable desktop-config capture are operational. The reviewed package split defines a Fedora KDE substrate, a portable KaleidashOS desktop base, and optional profiles. External application recipes and deployment bundles derived from the captured configuration are the next milestones.
