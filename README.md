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

## Planned structure

- Package, Flatpak, and repository inventories
- Niri and Noctalia configuration
- Terminal, Yazi, GTK, Qt, KDE, and Firefox theming
- Wallpaper-palette propagation
- Installation and update scripts
- Hardware-specific features isolated as optional profiles

## Status

Early development. The current milestone is to document and package an existing working Fedora 44 desktop before automating a clean installation.
