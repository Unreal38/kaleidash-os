# KaleidashOS Fastfetch identity

Copy the compact PNG into the Fastfetch configuration directory:

```fish
mkdir -p ~/.config/fastfetch
cp brand/logo/kaleidash-mark-compact.png ~/.config/fastfetch/
```

To preview the complete example without replacing an existing configuration:

```fish
fastfetch --config fastfetch/config.example.jsonc
```

The example uses `kitty-direct`, which is the fastest graphical image path in Kitty and requires a PNG with both logo dimensions configured. If the image is not visible, confirm that Fastfetch is running inside Kitty and that output is not being piped.

The OS module changes only Fastfetch's displayed label. It does not modify Fedora's `/etc/os-release` identity.
