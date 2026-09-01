# KaleidashOS configuration bundles

Configuration bundles reproduce portable desktop behavior without copying the user's complete home directory. Each bundle owns a narrow set of files, backs up pre-existing targets, and provides a matching restore script.

Available now:

- `capture/` - privacy-conscious collector for the current portable desktop configuration
- `lockscreen/` - wallpaper-reactive Noctalia 5 lock screen with KaleidashOS branding

Generated snapshots are written to `snapshot/` and remain review inputs until their corresponding deployment bundles are implemented.

Niri, Noctalia shell layout, terminal, application, GTK, and KDE deployment bundles will be derived from the reviewed snapshot.
