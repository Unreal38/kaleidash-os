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
- `fastfetch/` - example Fastfetch identity and graphical-logo configuration
- `identity/` - reversible local branding for metadata, desktop, terminal, greeter, GRUB, and Plymouth
- `inventory/` - privacy-conscious capture of packages, repositories, services, and component versions

## Planned structure

- Niri and Noctalia configuration
- Terminal, Yazi, GTK, Qt, KDE, and Firefox theming
- Wallpaper-palette propagation
- Installation and update scripts
- Hardware-specific features isolated as optional profiles

## Status

Early development. Identity is operational and the inventory collector is ready to capture the existing Fedora 44 desktop. The generated lists still require classification into a portable base and optional hardware profiles before they become installer inputs.
