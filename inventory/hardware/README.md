# Hardware profiles

Hardware-specific configuration must not enter the portable KaleidashOS base implicitly. After the initial inventory is captured, machine-specific packages and services will be moved into explicit opt-in profiles.

Likely profile categories include:

- AMD and NVIDIA graphics
- desktop and laptop power management
- monitor layouts and Moonlight/Sunshine display modes
- liquid cooling, RGB, and peripheral tools
- custom audio routing and channel swapping
- printers and scanners
- game controllers and vendor-specific input devices

Profiles may install packages, deploy narrowly scoped configuration, and enable services. They must remain optional, reversible, and safe to omit on different hardware.
