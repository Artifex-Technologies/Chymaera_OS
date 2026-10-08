#!/usr/bin/env bash
# shellcheck disable=SC2034
# Based on archiso's releng profile (archlinux/archiso configs/releng/profiledef.sh).

iso_name="chymaera"
iso_label="CHYMAERA_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Chymaera Linux <https://github.com/Artifex-Technologies/Chymaera_OS>"
iso_application="Chymaera Linux Live/Install Medium"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="chymaera"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd, not releng's xz. The installer copies this image (Calamares unpackfs), so
# decompression speed is install speed, and zstd decompresses several times faster
# than xz. The cost is a larger ISO; measure it from a CI build rather than
# trusting this comment, and revert to releng's
#   ('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
# if the size is not acceptable. See docs/INSTALLER.md.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
# releng also chmods /root/.automated_script.sh, /root/.gnupg, and three
# console-oriented /usr/local/bin scripts (choose-mirror, Installation_guide,
# livecd-sound) here — those are releng's own custom airootfs files for a
# console-first live session. Our live session boots into Plasma/SDDM with
# Calamares as the graphical installer, so those don't apply; only list
# paths that actually exist (created by the base/shadow packages themselves).
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  # sudo silently ignores any sudoers.d file that is group/world writable or
  # not owned by root, so this mode is load-bearing, not hygiene.
  ["/etc/sudoers.d/00-live-nopasswd"]="0:0:440"
  # Not a symlink and not created by any package, so without this line the
  # desktop-mode toggle would ship non-executable and SUPER + F12 would do nothing.
  ["/usr/local/bin/chymaera-desktop-mode"]="0:0:755"
  # Calamares runs this in the target after unpackfs; see etc/calamares/settings.conf.
  ["/usr/local/bin/chymaera-install-cleanup"]="0:0:755"
  # Trailing slash matters: mkarchiso only recurses (chown -fhR) when the path
  # ends in one. 1000:1000 is numeric because the live user does not exist at
  # build time -- sysusers.d/live.conf creates it at boot, pinned to uid 1000.
  ["/home/live/"]="1000:1000:700"
)
