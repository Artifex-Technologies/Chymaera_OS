# Installer

How Chymaera gets from the live USB onto a disk, why it is built that way, and
what has and has not been checked. Calamares is the installer; Omarchy was read
as a reference and is not used here. See "What we took from Omarchy".

## Status

| Piece | State |
| --- | --- |
| Calamares job sequence (`settings.conf`) | Written; modules checked against the Calamares 3.4.2 build. **Never run** |
| `unpackfs` from the live squashfs | Written; path derived from mkarchiso. **Never run** |
| `chymaera-install-cleanup` | Simulated against a mock target root (success, missing kernel, empty template). **Never run in a real install** |
| zstd squashfs | Set in `profiledef.sh`. **ISO size and install time not measured** |
| Calamares branding, partition and user defaults | Upstream defaults; see "Not done" |

Before this change the shipped installer could not have installed anything:
`INSTALL_CONFIG=ON` installs Calamares' own sample config, whose `unpackfs`
source is a developer file (`../CHANGES`), and whose sequence lists the
`initramfs` module that `packages/pkgbuilds/calamares/PKGBUILD` deliberately
does not build. Install speed was never the first problem; there was no working
install path to speed up.

## Design: copy the live image, do not rebuild it

```
mkarchiso  ──►  airootfs.sfs  (zstd squashfs, inside the ISO)
                    │
   live boot  ──►  mounted at /run/archiso/bootmnt/chymaera/x86_64/airootfs.sfs
                    │
   Calamares  ──►  partition, mount
                   unpackfs                (rsync the squashfs onto the disk)
                   shellprocess@cleanup    (chymaera-install-cleanup, chrooted)
                   machineid, locale, keyboard, fstab
                   initcpiocfg, initcpio   (regenerate the initramfs)
                   users, displaymanager, networkcfg, hwclock
                   bootloader (grub), umount
```

The installed system is a copy of what the user just ran, not a fresh
`pacstrap`. That is why the install is fast and why it works with no network:
nothing is resolved, downloaded or built on the target. It also matches the
project's rule that the live session must be useful air-gapped; the installer
inherits the same property. The cost is that the installed system starts as a
snapshot of the ISO's package versions, so the first thing a connected user
should do is `pacman -Syu`.

### Why speed comes from where it does

Install time is dominated by two things, and both are addressed:

1. **Unpacking the image.** Calamares mounts the squashfs and rsyncs it, so the
   bound is decompression plus disk writes. `profile/profiledef.sh` now builds
   the image with zstd instead of releng's xz. zstd decompresses several times
   faster; the price is a larger ISO.
2. **Rebuilding the initramfs.** The live image carries archiso's initramfs
   config, which compresses with `xz -9e`. `chymaera-install-cleanup` removes it,
   so the installed system uses Arch's stock config: zstd, and a single
   `default` image with no fallback.

**Neither effect has been measured.** The direction is well understood, the
magnitude is not, and the ISO size increase is a real trade-off. Measure both
from a CI build before relying on this, and revert `airootfs_image_tool_options`
to releng's xz line if the size is not acceptable. The original line is kept in
a comment in `profiledef.sh`.

### What `chymaera-install-cleanup` does, and why each step exists

`profile/airootfs/usr/local/bin/chymaera-install-cleanup` runs inside the target
straight after `unpackfs` and before anything that reads what it removes. Every
step answers something specific about the live image not being an installable
root:

| Step | Why |
| --- | --- |
| Restore `/boot/vmlinuz-linux` | mkarchiso runs `find /boot -mindepth 1 -delete` on the image, so the target has no kernel. The package's copy under `/usr/lib/modules/*/vmlinuz` survives, and the script installs it the way Arch's own pacman hook does |
| Regenerate `/etc/mkinitcpio.d/linux.preset` from `/usr/share/mkinitcpio/hook.preset` | The live preset is archiso's and builds an initramfs that looks for the live squashfs. Arch no longer ships a `linux.preset` in the kernel package; it generates one from this template, so we use the same template rather than a hand-written copy |
| Delete `/etc/mkinitcpio.conf.d/archiso.conf` | Its `HOOKS` would override whatever `initcpiocfg` writes, and its `xz -9e` slows the initramfs build |
| Delete the live `sudoers`, polkit and SDDM autologin files | They exist so a passwordless account can do anything; on an installed system they would grant that to every `wheel` user and autologin a user that no longer exists |
| Delete `kscreenlockerrc`, `sysusers.d/live.conf`, `tmpfiles.d/live-home.conf`, `/home/live` | Plasma's locker was disabled only because the live account has no password; the other two recreate the live user on every boot |
| Copy `/home/live/.config` into `/etc/skel` | The desktop config (both Hyprland looks and the Plasma fallback) lives in the live user's home. Without this the installed user gets a bare desktop |
| Initialise the pacman keyring if the image has none | The installed system needs it for `pacman -Syu` and for Sarina to install anything. releng ships a `pacman-init.service` for the live medium; this profile does not, so whether the squashfs carries a keyring is unverified and the script covers both cases |

It fails loudly (non-zero exit) if the kernel is missing or the preset template
is empty or malformed. Both would otherwise produce an install that completes
and then does not boot.

When you add a live-only file to `profile/airootfs/etc/`, add it to the
`live_only` list in that script too. Nothing checks the two lists against each
other.

### Offline

The welcome page's requirement list is Calamares' default: only RAM is
*required*, and the internet check is advisory. An offline install therefore
works. The unpack, the cleanup and the initramfs rebuild need no network.

## What we took from Omarchy

Read from the `quattro` branch of the Omarchy repo (MIT) and from
`omacom/try-omarchy-windows`, through GitHub's web pages. These are second-hand
summaries, so treat the counts as approximate.

- Omarchy's `install/` directory holds package lists and post-install and
  provisioning scripts: `omarchy-base.packages` (~152 packages),
  `omarchy-other.packages` (~63, hardware-specific: NVIDIA, Broadcom, T2 Macs,
  Framework, Dell) and directories `config`, `hardware`, `helpers`, `login`,
  `post-install`, `provisioning`, `user`. **The partitioning and base-system
  install is not in that repo.** We did not find the code behind the roughly
  one-minute install that prompted this work, so we do not know how they get
  that figure. Plausible causes are a small package set, a prebuilt package
  repo and an image-based install, but that is a hypothesis.
- `try-omarchy-windows` runs Omarchy in QEMU on the Windows Hypervisor Platform
  from a ~2 GB prebuilt Arch guest image. It is a way to *try* Omarchy, not an
  installer, but it does show an image-first model.

Ideas worth borrowing, none adopted yet:

- **Hardware-conditional package lists.** A base list plus lists installed only
  when matching hardware is detected, instead of shipping every GPU and Wi-Fi
  driver in the image.
- **First-boot provisioning.** Creating the user and doing slow setup after the
  first boot rather than inside the installer.
- **Migrations.** Versioned scripts that carry installed systems forward across
  releases. Chymaera has nothing equivalent.

Why Chymaera does not use Omarchy's installer: it is built around Omarchy's own
bootloader, snapshot and package layout, and an ISO that does not ship a
base system for it to install onto. Chymaera keeps its own live ISO and
Calamares. The longer reasoning is in [DESKTOP.md](DESKTOP.md).

## Not done

- **Never run.** The first real test is to boot the built ISO in a VM, run
  Calamares, reboot and log in. Things most likely to need a fix: the unpack
  path, the keyring step, GRUB on BIOS versus UEFI, and whether Calamares logs
  show the cleanup script running chrooted as expected.
- **Branding.** `branding: default` is Calamares' sample, including its squid
  logo. A `chymaera` branding directory (`branding.desc`, logo, slideshow,
  stylesheet) is still to do.
- **Partition and user defaults.** Upstream's: ext4, GRUB, a default hostname of
  `derp-${cpu}`. Overriding `users.conf` means copying the whole upstream file,
  because Calamares does not merge partial module configs.
- **Required disk space.** Upstream's `requiredStorage` is 5.5 GB, which is
  below what this image needs. The real installed size has not been measured.
- **Agent-assisted install.** Install-time tool selection is Sarina's job and
  does not exist yet; see [ARCHITECTURE.md](ARCHITECTURE.md).
- **Hyprland as the installed default.** The installed system keeps whichever
  SDDM session the user picks; the live medium autologins Plasma. See
  [DESKTOP.md](DESKTOP.md) for the phasing.
