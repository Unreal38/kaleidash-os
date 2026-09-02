# Configuration capture

This collector turns the current desktop settings into a narrow, reviewable source snapshot. It is intentionally separate from the future deployment layer: captured files are evidence of the working setup, while deployment bundles will normalize and install the reviewed result.

## Capture

Run as the normal desktop user from the repository root:

```fish
./config/capture/collect.sh
git add -N -- config/snapshot
git diff -- config/snapshot
./config/capture/validate-snapshot config/snapshot
```

`git add -N` records only intent-to-add, making new snapshot files visible to `git diff` without staging their contents.

The collector reads only entries in `allowlist.tsv`. Missing applications are skipped. The generated `config/snapshot/manifest.tsv` records normalized modes and SHA-256 checksums.

## Included boundary

- Niri configuration and local Niri shell scripts
- Noctalia declarative TOML and GUI-managed widget/settings state
- Kitty, Fish, Starship, Fastfetch, Yazi, and ncspot configuration
- GTK, KDE globals, Qt5ct, Qt6ct, Kvantum, Fontconfig, and environment fragments
- Declarative Noctalia Greeter and greetd configuration

The existing `config/lockscreen/` bundle remains authoritative for lock-screen generation. Capturing Noctalia state preserves GUI widget placement without replacing that generator.

## Portability and privacy

The collector replaces the current home, XDG directories, username, hostname, and active Niri output names with tokens. It removes Noctalia location settings and the Greeter's machine-specific `[output]` and `[user]` sections.

Credential assignments are replaced only in the staged snapshot with named placeholders such as `@SECRET_NOCTALIA_WALLHAVEN_API_KEY@`; the live source file is never edited. Required placeholder names are listed in `config/snapshot/secrets.required` without values. A future deployment step will restore these locally from an untracked secrets file or prompt, never from Git.

It never reads Noctalia Greeter `sync.toml`, wallpaper files, shell history, browser data, SSH/GPG material, keyrings, caches, application login state, or broad home-directory trees. The validator rejects symlinks, binary/large files, private-key material, unredacted home paths, email addresses, embedded URL credentials, and common credential assignments.

The snapshot may still contain personal styling choices and command paths. Always inspect the Git diff before committing it to the public repository.
