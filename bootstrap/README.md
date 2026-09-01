# KaleidashOS bootstrap installer

The bootstrap layer turns the reviewed manifests into an ordered, repeatable Fedora installation. It installs package names rather than captured versions, so normal DNF, Flatpak, and Fedora release upgrades remain authoritative.

## Inspect the default plan

The default command is non-mutating:

```fish
./bootstrap.sh
```

This validates the manifests and prints the repositories, packages, Flatpaks, services, external applications, and identity work that would be applied.

List and select optional profiles:

```fish
./bootstrap.sh profiles
./bootstrap.sh plan --profile development --profile gaming
```

## Install

Run the installer as the normal desktop user:

```fish
./bootstrap.sh install
```

Use `--yes` for non-interactive package-manager confirmation. Optional profiles are never installed unless requested. `--no-identity` skips `identity/install.sh` while retaining the package and application layers.

The operation is idempotent: DNF and Flatpak reconcile already-installed entries, repository commands can be reapplied, the identity installer keeps its original backups, and services are only enabled when their unit files exist.

## Installation order

1. Verify Fedora from `/usr/lib/os-release`, not the branded `/etc/os-release`.
2. Validate and merge the base, default-application, and selected-profile manifests.
3. Enable COPR, Terra, RPM Fusion, Fedora Cisco OpenH264, and profile repositories through explicit recipes.
4. Install current package versions from the target Fedora release.
5. Add Flatpak remotes and install the requested application branches.
6. Apply the reversible KaleidashOS identity layer.
7. Enable available services without starting them during the current desktop session.

No version locks, DNF release variables, Fedora repository replacements, signing-key replacements, or automatic `dnf upgrade` operations are introduced.

## Deliberately deferred

- Consulo, SourceGit, Unity Hub, pokemon-colorscripts, and other `external.txt` entries are reported but not installed until each has a verified upstream recipe.
- `greetd.service` is not activated yet. Switching away from SDDM before the Noctalia Greeter package and configuration are reproducibly deployed could leave a new installation without a working login screen.
- Personal configuration and credentials are outside this milestone. Portable Niri, Noctalia, terminal, application, and Waylandcraft configuration comes next.

## Tests

```fish
./bootstrap/tests/test-bootstrap.sh
```

The test suite uses a Fedora metadata fixture and exercises only plan resolution. It never invokes `sudo`, DNF, Flatpak, or systemd mutations.
