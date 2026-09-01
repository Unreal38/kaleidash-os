# Reproducible system inventory

This directory records the portable intent of the working KaleidashOS machine. It is not a disk image and it does not attempt to pin Fedora repositories to historical package builds.

Run the collector as the normal desktop user:

```fish
./inventory/collect.sh
```

The collector does not use `sudo`. It reads Fedora's vendor identity from `/usr/lib/os-release`, so the result records Fedora 44 even when `/etc/os-release` is branded as KaleidashOS.

## Generated files

| File | Purpose |
|---|---|
| `packages/dnf-userinstalled.txt` | Sorted package names requested by the user, groups, or profiles. This will become the portable DNF install input. |
| `packages/dnf-reference.tsv` | Package name, EVR, architecture, install reason, and source repository for diagnosis and historical reference. |
| `packages/flatpak-apps.tsv` | Scope, application ID, origin, branch, and reported version. Runtimes are omitted because Flatpak resolves them as dependencies. |
| `repositories/dnf-enabled.tsv` | Enabled DNF repository ID and display name. No repository URLs or configuration files are copied. |
| `repositories/flatpak-remotes.tsv` | Scope, remote name, and sanitized URL. URL credentials, queries, fragments, and local paths are removed. |
| `services/system-enabled.txt` | Persistently enabled system unit files. |
| `services/user-enabled.txt` | Persistently enabled user unit files. |
| `system/base.env` | Fedora vendor ID, release, variant, platform, and CPU architecture. |
| `system/component-versions.tsv` | Reference versions for the shell, compositor, terminal, and related tools when available. |

The DNF package list uses `repoquery --installed --userinstalled`, which captures packages installed by user request or through groups/profiles rather than every dependency. The reference file remains diagnostic only; a future bootstrapper should install package names and let the target Fedora release resolve compatible versions.

## Privacy boundary

The collector deliberately does not read or copy:

- home-directory configuration files
- Wi-Fi or NetworkManager profiles
- browser profiles
- SSH or GPG material
- passwords, API tokens, cookies, or credentials
- hostnames, machine IDs, hardware serial numbers, or host keys
- complete DNF `.repo` files
- monitor layouts or other hardware configuration

Flatpak URLs are sanitized before writing. The collector also scans its staged outputs for home paths, embedded URL credentials, private-key headers, and common credential parameters. If a suspicious value is found, it aborts before replacing the repository inventory.

## Review before committing

These lists describe the current machine, not yet the final portable base. Review them for:

- temporary applications and experiments
- old compatibility packages
- development tools that should be optional
- services specific to this computer
- GPU, cooling, controller, printer, and streaming packages
- third-party repositories that should require explicit opt-in

The next milestone will classify the reviewed inventory into the KaleidashOS base and optional profiles.
