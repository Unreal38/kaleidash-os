# KaleidashOS manifests

These files translate the captured workstation into portable intent. They do not replay every installed RPM.

The Fedora KDE image remains the substrate. Packages recorded with DNF's `Group` reason, dependency packages, kernels, firmware, and generated service units are left to Fedora unless a profile explicitly needs them.

## Layers

| Layer | Purpose | Default |
|---|---|---|
| `base/` | Niri, Noctalia, terminal tools, wallpaper integration, identity dependencies, and required repositories | Yes |
| `default-applications/` | Daily applications explicitly included in the KaleidashOS edition | Yes |
| `profiles/desktop-extras/` | Useful additions that are part of this workstation but not required by the shell | Optional |
| `profiles/development/` | Unity/general development libraries and toolchains | Optional |
| `profiles/gaming/` | Additional Wine, emulator, communication, and gaming tools | Optional |
| `profiles/creative/` | Art, audio, diagramming, recording, and reference tools | Optional |
| `profiles/remote-access/` | Tailscale, Sunshine, and remote-display tools | Optional |
| `profiles/hardware-amd/` | AMD-specific acceleration and diagnostics | Optional |
| `profiles/hardware-cooling/` | NZXT/liquid cooling support | Optional |
| `profiles/hardware-epson/` | Epson printer utility and printing activation | Optional |
| `profiles/compatibility/` | Snap compatibility for applications that still require it | Optional |

`dnf.txt` files contain captured package names. `dnf-additions.txt` records required Fedora packages added after capture. `flatpak.tsv` uses the columns `scope`, `application`, `origin`, and `branch`; `flatpak-additions.tsv` uses the same format for newly requested applications. Service lists contain units that a future installer may enable after the corresponding packages and configuration are deployed.

Items installed from downloaded RPMs or vendor installers live in `external.txt`; they require a verified source and installation recipe before automation.

## Validation

Run:

```fish
./manifests/validate.sh
```

Validation checks sorting, duplicates, captured-package membership, repository IDs, Flatpak references, and service names. It deliberately does not install or enable anything.

## Classification policy

- Fedora KDE group packages are provided by the installation image.
- Package versions in the inventory are reference evidence, not hard pins.
- Dependencies are resolved by the target Fedora release.
- Hardware and workstation administration remain opt-in.
- A package may appear in only one DNF or DNF-additions manifest.
- Nothing in `review/` is an installer input.
