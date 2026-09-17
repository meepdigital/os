# Five Git-based installer strategies

1. **Immutable image repository.** Keep the prebuilt Meep root filesystem, package manifests, installer assets, and boot metadata in GitHub Releases or Git LFS. The installer verifies a signed commit/release, materializes the tree, then creates the squashfs and ISO locally.
2. **Layered core plus overlay.** Store `/usr`, `/etc` templates, and system scripts in a Meep core repository. Store user or hardware-specific layers as separate commits and merge them during installation. This makes core upgrades and user diffs reviewable.
3. **Git-driven image builder.** Clone a declarative repository containing package lists, scripts, systemd units, desktop files, and a build lockfile. Run the existing `sh/*.sh` pipeline in a clean build VM, export the merged root, and burn the resulting ISO. Git is the source of intent, not a live root filesystem backup.
4. **Home repository enrollment.** Let a user provide a GitHub URL or upload a deploy key/token for a private repository containing selected `/home/<user>` files. Clone into a staging directory, allow a path-by-path preview, restore ownership and permissions, and refuse secrets unless explicitly selected.
5. **Core-relative backup.** Record the exact Meep core commit and a manifest of user/system files. Use Git trees and diffs to store only changed files relative to that commit; large binaries go to Git LFS or object storage. Restore into a disposable staging tree, compare, then atomically apply it.

Live synchronization should be opt-in and conflict-aware: use a local bare repository or Syncthing-like staging queue, push signed commits, and never overwrite a second machine silently. GitHub tokens belong in the keyring, and an ISO build must verify checksums, signatures, file ownership, capabilities, device nodes, and boot artifacts after checkout.

