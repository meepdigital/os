# Ubuntu Meep installer

This directory is the source of the future custom Node.js installer.

The installer is launched only in the `Ubuntu Meep - Install Current System`
boot mode. Its source of truth is the running merged live root:

```text
read-only Ubuntu Meep base + writable persistence = current Ubuntu Meep
```

It must install that merged system. It must not install the original ISO
layer, invoke Ubiquity, invoke Subiquity, or invoke Ubuntu Cinnamon Installer.

The implementation is intentionally not built yet.
