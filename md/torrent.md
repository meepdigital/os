# Torrenting the installer

## Five ways to acquire the OS after Wi-Fi setup

1. **NetworkManager-assisted bootstrap.** Ask for an SSID and password through a local GTK/Electron page, create a temporary NetworkManager connection, then download a signed `.torrent` or magnet for the complete OS and verify its Merkle/hash manifest before writing.
2. **Piecewise root filesystem.** Torrent a content-addressed archive of the Meep root and a separate EFI/kernel/initramfs bundle. Seed from a tracker/DHT and resume missing pieces; assemble only after every required hash passes.
3. **VM-assisted installer.** Run a small unprivileged torrent client in the live environment, expose progress to the installer, and let a privileged helper write the verified image. This isolates networking from disk mutation.
4. **Local seed or LAN cache.** Prefer a signed Meep torrent from a local peer/cache, falling back to public seeders. This lowers hosted bandwidth while retaining a cryptographic root manifest.
5. **Delta torrents.** Torrent a base ISO plus block-level update torrents keyed by the exact base digest. This is efficient, but only safe with strict version/architecture checks and a final whole-image verification.

## Five ways to synchronize shared command folders

1. **Subscribed signed bins.** Users subscribe to a publisher's `/bin` repository/torrent; binaries land in a read-only content-addressed store and are exposed through a generated PATH overlay only after signature and policy checks.
2. **Capability packages.** Publish commands with manifests declaring architecture, libc, permissions, dependencies, and sandbox requirements. A client accepts selected packages, not an uncontrolled remote PATH.
3. **Node module swarms.** Torrent npm package tarballs and native build artifacts by lockfile/content hash. Reuse them from a global pnpm-style store, while rebuilding node-gyp addons when the Node/Electron ABI differs.
4. **Collaborative shell channels.** Subscribe to curated channels for admin, media, development, or accessibility commands. Each channel has maintainers, revocation lists, staged rollout, and rollback to the previous signed tree.
5. **Small native helpers.** Distribute precompiled C utilities for narrowly defined tasks such as checksums, filesystem inspection, compression, or hardware probes. Ship source, reproducible build metadata, SBOM, signature, and a sandbox profile alongside each binary.

Remote binaries must never execute merely because they arrived in a torrent. Use signatures, review, least privilege, seccomp/AppArmor or containers, architecture checks, and an explicit user/system-admin approval boundary.

