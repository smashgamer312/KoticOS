# KoticOS (ASM) — tiny hobby OS

Features:
- Boots via GRUB (Multiboot2) on BIOS/UEFI (via GRUB)
- 32-bit protected mode, VGA text console
- Commands: `/help`, `/echo <text>`, `/reboot`, `/shutdown`, `/sysinfo`, `/cls`, `/explorer`
- `/explorer` shows a minimal GUI demo using the framebuffer

## Build locally (Linux PC)
Requirements: `nasm`, `grub-mkrescue`, `xorriso`, `i386-elf-binutils`, `qemu-system-x86`

```bash
sudo apt-get install nasm grub-pc-bin xorriso qemu-system-x86 binutils gcc
brew tap nativeos/i386-elf-toolchain   # on macOS (with brew)
```

Build:
```bash
make
qemu-system-i386 -cdrom KoticOS.iso
```

## Build on GitHub Actions (recommended from phone)
1. Create a new GitHub repo and upload all files.
2. Actions will produce `KoticOS.iso` artifact on each push.

## Termux note
Building ISO on Android is tough (no `grub-mkrescue`). Use GitHub Actions instead.

## Keys
- Type commands starting with `/`
- Exit GUI demo: press Enter
- Reboot may not work in emulators without proper permissions.