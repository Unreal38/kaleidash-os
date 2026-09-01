# KaleidashOS lock screen

This bundle uses Noctalia 5's native `ext-session-lock-v1` implementation as the default KaleidashOS lock screen. The Fedora `swaylock` package remains installed as a fallback, but it is not the primary renderer.

The native lock screen is a better fit for KaleidashOS because it consumes Noctalia's current wallpaper and palette directly. It does not need to generate a blurred screenshot before every lock.

## Design

- Current wallpaper on every output, blurred at `0.70`
- Wallpaper-derived `surface` tint at `0.30`
- Dynamic prismatic KaleidashOS logo above the login control
- Compact centered login element using `surface_variant`, rounded corners, and the active primary accent
- Per-output placement generated from Niri's current logical dimensions
- Swaylock fallback if Noctalia IPC is unavailable

The logo is loaded when the lock surface opens, so wallpaper-generated logo changes are visible on the next lock without a separate cache or watcher.

## Install and test

Run from a live Niri session after the identity layer has been installed:

```fish
./config/lockscreen/install.sh
kaleidash-lock
```

The installer reads `niri msg --json outputs`, generates `~/.config/noctalia/kaleidash-lockscreen.toml`, installs `~/.local/bin/kaleidash-lock`, validates the merged Noctalia config, and reloads Noctalia.

Use `kaleidash-lock` for Niri keybindings and other session-lock integrations. The complete Niri configuration milestone will make that binding the default.

Noctalia's editor can fine-tune the generated positions while unlocked:

```fish
noctalia msg lockscreen-widgets-edit
```

The editor writes overrides to Noctalia's `settings.toml`. Re-running this installer regenerates the declarative layer but deliberately does not destroy editor overrides.

## Restore

```fish
./config/lockscreen/uninstall.sh
```

This restores pre-existing files. It does not uninstall Swaylock or alter PAM.

## Test the generator

```fish
./config/lockscreen/tests/test-lockscreen.sh
```
