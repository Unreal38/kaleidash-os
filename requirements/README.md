# KaleidashOS product requirements

This is the authoritative scope for the default KaleidashOS edition. An item listed here is expected to be installed and configured unless explicitly marked optional. Raw inventory is evidence, while `manifests/` is the installation-oriented package split.

## Default applications

| Component | Delivery | Required configuration |
|---|---|---|
| Steam | DNF/RPM Fusion through the captured `steam-arch-transition` package | Desktop integration only; never copy account data |
| Vesktop | DNF/Terra | Niri screen sharing and portal behavior |
| Thunar | DNF | Theme and preferred-terminal integration |
| ncspot | Flathub | Wallpaper-generated theme; never copy Spotify OAuth credentials or cache |
| Yazi | DNF/Terra | Theme, keymaps, opener rules, and Kitty image support |
| Kitty | DNF | Font, padding, opacity, and wallpaper palette integration |
| Sunshine | Flathub | Sanitized application/display templates; never copy certificates, PINs, credentials, or device pairings |
| Unity Hub | Vendor/external | Desktop entry and installation recipe; no Unity account data |
| Consulo | Upstream/external | `/opt` installation, desktop entry, and Unity project support |
| SourceGit | Upstream/external | Desktop entry and Git/SSH agent integration; no credentials |
| btop | DNF | Wallpaper-derived theme |
| pokemon-colorscripts | Upstream/external | Fish/terminal startup integration |
| cmatrix | DNF | No personal state |
| Noctalia Greeter | greetd plus KaleidashOS identity scripts | Wallpaper palette, logo, session selection, and passwordless privileged sync policy |
| Prism Launcher | DNF/Terra | Waylandcraft instance manifest and launch/session integration; no Microsoft account data |

## Desktop and settings

The following behavior is part of the default edition:

- Niri is the primary session, including keybindings, window rules, output-independent layout behavior, fonts, portals, autostart, and Noctalia integration.
- Noctalia provides the panel, launcher, notifications, wallpaper/palette propagation, plugins, desktop widgets, media integration, and session controls.
- Noctalia Greeter uses the active wallpaper-derived palette and KaleidashOS identity.
- KDE remains the Fedora substrate and fallback session. KDE/Qt settings keep KDE applications visually consistent under Niri.
- Swaylock is installed and themed from the current wallpaper palette.
- Niri and KDE font choices are reproduced consistently.
- The Waylandcraft Prism instance is exposed as a separate login session without modifying the normal Niri or Plasma sessions.

## Configuration bundles

| Bundle | Scope |
|---|---|
| Niri | Keybindings, window rules, environment, autostart, portals, fonts, and Noctalia startup |
| Noctalia | Shell settings, panel modules, plugins, wallpaper behavior, desktop widgets, and palette generation |
| Noctalia Greeter | greetd session, greeter settings, branding, wallpaper sync, and privilege policy |
| Kitty | Terminal appearance, font, padding, shell integration, and dynamic colors |
| Fish | Interactive configuration, aliases, functions, Starship initialization, and pokemon-colorscripts startup behavior |
| Starship | Prompt modules and palette integration |
| GTK/Thunar | GTK 3/4 theme settings and Thunar preferences, without bookmarks containing personal paths |
| KDE/Qt | KDE globals, icons, fonts, color scheme, Qt6ct, and Kvantum settings |
| Yazi | Theme, keymaps, file openers, preview rules, and Kitty integration |
| ncspot | Theme and safe preferences only; authentication cache is excluded |
| Swaylock | Lock-screen layout, fonts, image/palette behavior, and invocation from Niri/Noctalia |
| Fastfetch | KaleidashOS identity, layout, dynamic logo, and recache integration |
| Firefox | Wallpaper-compatible chrome/theme settings where portable and safe |
| Sunshine | Sanitized application definitions and hardware-neutral display-script templates |
| Waylandcraft | Login-session desktop file, launcher, Prism instance metadata, mods/config manifest, and display selection |

## Supporting platform components

These are required even though they are not user-facing applications:

- Fish, Starship, Fastfetch, greetd, Swaylock, app2unit, Quickshell, wl-clip-persist, cliphist, Grim, Slurp, Swappy, mpv/mpvpaper, FFmpeg, GTK/Qt theming tools, fonts, portals, keyring support, and KaleidashOS identity services.
- Wallpaper assets or a documented wallpaper source are required for the desktop's defining palette workflow.

## Explicit privacy exclusions

Never commit or package:

- Spotify OAuth credentials, ncspot cache, or listening history
- Steam, Discord, Vesktop, Microsoft, Minecraft, Unity, GitHub, or Git credentials and sessions
- SSH/GPG private keys, keyrings, tokens, cookies, browser profiles, or password stores
- Sunshine certificates, credentials, PINs, pairings, or host UUIDs
- Prism Launcher `accounts.json`, Minecraft saves, logs, screenshots, crash reports, or server addresses
- Wi-Fi/NetworkManager profiles, hostnames, machine IDs, serial numbers, MAC addresses, or runner identities
- Personal bookmarks, recent-file lists, absolute home paths, project history, or private repository URLs
- Hardware-specific monitor names and scripts in the portable base; use opt-in templates/profiles

## Optional profiles retained

The existing development toolchain, additional gaming/emulation tools, creative tools, Tailscale, AMD acceleration, NZXT cooling, Epson printing, and Snap compatibility remain supported opt-in profiles. The applications explicitly listed above are default even if they previously lived in one of those profiles.
