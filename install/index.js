#!/usr/bin/env node

// This is the deliberate boundary for the Ubuntu Meep installer. The live
// image launches it only from the GRUB entry containing meep.install=1.
// Implementation will install the current merged live root, including the
// writable persistence layer; it must never fall back to the ISO squashfs.
console.error('Ubuntu Meep current-system installer is not implemented yet.');
process.exitCode = 1;
