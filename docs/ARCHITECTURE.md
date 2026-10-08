# Architecture

## Layers

1. **Base**: Arch Linux, built via [archiso](https://github.com/archlinux/archiso).
   `profile/` is a fork of archiso's `releng` profile (`profiledef.sh`,
   `packages.x86_64`, `pacman.conf`), kept close to upstream so Arch's own
   install/live-boot support (hardware drivers, `archinstall`, rescue tools)
   isn't quietly lost to hand-trimming.
2. **Security tooling**: [BlackArch](https://github.com/BlackArch/blackarch),
   added as a repo (`[blackarch]` in `profile/pacman.conf`) rather than
   forked. The ISO bakes in only a small hand-picked core (~27 packages in
   `profile/packages.x86_64`); everything beyond it is installed after the
   fact, agent-assisted, by Sarina. See "Tool delivery" below for why.
3. **Desktop**: two sessions, selectable at the SDDM greeter. An
   [Omarchy](https://github.com/omacom/omarchy)-derived Hyprland session with a
   switchable macOS-style "stealth" look is the intended primary; KDE Plasma
   (`plasma-meta` + `sddm` + Dolphin, Konsole, Kate, Ark, Okular) is the
   fallback and is still the live medium's autologin session until Hyprland is
   made the default. NetworkManager and PipeWire serve both
   (`profile/packages.x86_64` layers these on top of releng's more
   CLI/live-boot-oriented networking and audio stack). The Hyprland design and
   what is unverified are in [DESKTOP.md](DESKTOP.md).
4. **Installer**: [Calamares](https://codeberg.org/Calamares/calamares) as
   the primary graphical, live-session installer (a graphical wizard suits a
   live USB better than `archinstall`'s TUI). It's AUR-only, not in Arch's
   official repos, so it's vendored at `packages/pkgbuilds/calamares` and
   built the same way as Sarina, into the `[chymaera]` repo. It installs by
   copying the live squashfs rather than running `pacstrap`, which is what
   makes it quick and lets it work offline; its configuration ships in
   `profile/airootfs/etc/calamares/`. How and why, and what is unverified, is
   in [INSTALLER.md](INSTALLER.md). `archinstall` stays in `packages.x86_64`
   (from releng) as a CLI/scripted alternative.
5. **AI agent**: [Sarina](https://github.com/Artifex-Technologies/Sarina), a private
   repo vendored as a git submodule at `packages/sarina`, packaged for the
   ISO by `packages/pkgbuilds/sarina-git`.

## Tool delivery: a small baked-in core, then Sarina

Kali ships a curated default set (`kali-linux-default`) rather than every tool
in its repos, to keep the base system usable. Chymaera originally copied that
shape by baking in fifteen `blackarch-*` category groups. **That approach was
abandoned**; the ISO now ships a small hand-picked core and defers the rest to
Sarina at install time.

### Why the categories were dropped

The category list was never validated, and when CI first got far enough to try
it, it failed in three separate ways:

- **Unresolvable dependencies.** `yinjector`, `limelighter` and `thefatrat`
  need `lib32-*` packages, which forced `[multilib]` on. Enabling it fixed
  those three and said nothing about the thousands of packages behind them.
- **Silent provider roulette.** Six virtual dependencies had multiple
  providers, so pacstrap printed a numbered menu for each — `tessdata` alone
  offered 128 — and, being non-interactive, took option 1 every time. That is
  how the ISO nearly shipped with Afrikaans OCR data.
- **Size.** The resolved set did not fit on a CI runner and would have made a
  multi-tens-of-GB ISO. It killed the GitHub runner outright, which uploads no
  log at all when it dies, making the failure invisible.

Behind all three is one problem: nobody had decided what those ~3,000 packages
were *for*. A category group is a guess about what a user wants, made by
someone who has never met them.

### What ships on the ISO now

A hand-picked core covering recon, capture, wireless, password attacks, web,
exploitation, reversing and forensics. Named packages, not groups — the size
is predictable and the conflict surface is nearly nil. Verified against live
repos: 837 packages resolved including dependencies, no provider menus, no
conflicts, ~3.2 GiB compressed.

The core exists for one reason worth stating plainly: **the live session has
to be useful with no network.** Air-gapped client sites, SCIFs and offline
forensics are exactly where a live USB earns its keep, and they are the one
thing a download-on-demand model cannot serve. `blackarch-keyring` ships too,
so the installed system trusts `[blackarch]` and can expand later.

### What Sarina owns

Everything past the core:

- **Guided install-time selection** — asking what the machine is for and
  installing accordingly, instead of guessing on the user's behalf.
- **Categorisation.** BlackArch packages drop bare binaries into `/usr/bin`
  with no menu entry — the exact problem Kali's curated menus solve. Sarina
  generates `.desktop` entries and Plasma menu categories as tools are added,
  so the organisation is maintained rather than hand-written here.

Neither exists yet. Until they do, the core is all the distro ships, and that
is a deliberate floor rather than a placeholder — see "Open questions".

## Validating additions: `blackarch_compat`

The agent submodule ships a purpose-built harness at
`packages/sarina/blackarch_compat/`: it installs one `blackarch-*` category
(or an explicit combination, with `--combo`) at a time inside a disposable
Docker container and records whether the install goes cleanly.

```bash
cd packages/sarina
python3 -m blackarch_compat.run_tests --all -o report.json --markdown report.md
```

Its role has shifted with the change above. It is no longer a gate on the ISO
package list — that list is now small enough to verify directly:

```bash
# on an Arch host with [blackarch] configured
mapfile -t PKGS < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' profile/packages.x86_64 | grep -vx -e calamares -e sarina-git)
pacman -Sp --print-format '%r/%n' "${PKGS[@]}"
```

Instead it becomes the safety check behind *Sarina's* install-time
suggestions: before the agent offers a category, it should know that category
installs cleanly alongside what is already present. As of this writing the
harness is unit-tested but **has not been run against a real Docker daemon**
(see its own README's Status section).

What it catches: install-time conflicts (`pacman -S` failures, `pacman -Qk`
file-manifest mismatches). What it doesn't: runtime conflicts between tools
(port/config/venv collisions), or anything that only shows up on the actual
built ISO — for that, a local [archiso](https://github.com/archlinux/archiso)
checkout's `scripts/run_archiso.sh` boots a built ISO in QEMU.

## Live session

The live medium autologins a passwordless `live` user straight into Plasma
(Wayland). Everything in this section is live-medium only: the installer strips
it from the installed system (`chymaera-install-cleanup`, see
[INSTALLER.md](INSTALLER.md)). Getting here took three things that are each easy
to get wrong:

**The user is created by `sysusers.d`, not by shipping `/etc/passwd`.**
archiso's releng profile ships a two-line `airootfs/etc/passwd` containing only
root, and that is safe *for releng* because nothing in its package set needs a
service account. It is not safe here. mkarchiso copies `airootfs/` over the
pacstrapped root and never re-runs `systemd-sysusers`, so a hand-written
`passwd` silently deletes all 38 accounts the image already has — including
`sddm` (uid 954), without which the greeter cannot start.
`airootfs/etc/sysusers.d/live.conf` sidesteps this: `systemd-sysusers.service`
runs at boot, before `sysinit.target`, and adds the account to the real
`/etc/passwd`.

**`systemd-firstboot` has to be masked.** mkarchiso deliberately writes
`/etc/machine-id` as the literal string `uninitialized` so systemd generates a
fresh id per boot. That also makes `ConditionFirstBoot=yes` true, so
`systemd-firstboot` runs and interactively asks for timezone, locale, hostname
and root password before anything graphical starts — on a live ISO, a dead end.
Shipping a real machine-id does not help, because mkarchiso overwrites it. So
`airootfs/etc/systemd/system/systemd-firstboot.service` is a symlink to
`/dev/null`.

**Passwordless means every auth prompt must be removed, not just the login
one.** The account has no password, so anything that asks for one strands the
user. That is why the profile also ships `sudoers.d` and a polkit rule granting
`wheel` unprompted access, and disables Plasma's screen locker via
`/etc/xdg/kscreenlockerrc`. All three are live-medium only: Calamares writes
the installed system's own policy, and `chymaera-install-cleanup` deletes the
live files so none of this reaches it. That script keeps its own list of these
files, so a new live-only file has to be added there too.

## Desktop look

> **Direction change.** The primary desktop is moving from Plasma to an
> Omarchy-derived Hyprland session with a switchable macOS-style "stealth" look;
> Plasma stays as a fallback session. Design, status and what is unverified are
> in [DESKTOP.md](DESKTOP.md). Until Hyprland is boot-tested and made the
> autologin default, the description below is still what the live session ships.

The live session ships a macOS-like desktop: [MacTahoe](https://github.com/vinceliuice/MacTahoe-kde)
aurorae window decorations with traffic-light buttons on the left, matching
colour schemes, Plasma desktop theme, SDDM greeter theme, Kvantum widget
style, and the MacTahoe icon/cursor themes. Both light and dark variants
install; the session defaults to dark and either can be selected in System
Settings, which is why both are packaged rather than just one.

Two deliberate departures from upstream:

- **No dock.** The look-and-feel package ships
  `layouts/org.kde.plasma.desktop-layout.js`, a macOS layout with a top bar
  and a dock. It is not installed. Chymaera keeps Plasma's stock bottom
  panel, so the theme is applied as individual settings (colour scheme,
  decoration, desktop theme) rather than by setting `LookAndFeelPackage`,
  which could pull the layout in with it.
- **Button order is `XIA`, not upstream's `XAI`.** Upstream's look-and-feel
  `defaults` and its own aurorae rc disagree with each other; `XIA` is
  close/minimize/maximize, which is what macOS actually does and what the
  decoration's `LeftButtons` says.

The theme is vendored as two PKGBUILDs pinned to upstream commits, split so
the 84 MB icon set can be dropped independently if the ISO needs to slim
down -- everything else still works, just with Breeze icons.

Defaults reach the live user through `airootfs/home/live/.config/`, chowned
recursively by a `file_permissions` entry whose path ends in `/` (mkarchiso
only recurses for those). The uid is hardcoded to 1000 to match the pin in
`sysusers.d/live.conf`, because the account does not exist at build time.

## Package flow for Sarina

```
packages/sarina/            (git submodule, tracks Sarina)
        │
        ▼  scripts/build-local-packages.sh
packages/pkgbuilds/sarina-git/PKGBUILD
        │  (makepkg, run as a regular user)
        ▼
repo/x86_64/*.pkg.tar.zst + chymaera.db   (local pacman repo, gitignored)
        │
        ▼  scripts/build.sh → mkarchiso, using profile/pacman.conf's [chymaera] repo
out/*.iso
```

Advancing Sarina to a new commit is:

```bash
./scripts/update-sarina.sh   # git submodule update --remote --merge, staged
git commit -m "Update Sarina"
```

The distro repo's `packages/pkgbuilds/sarina-git/PKGBUILD` builds directly
from whatever commit `packages/sarina` is checked out to — no tagged
release needed for local/dev/CI builds. The AUR-facing PKGBUILD that builds
from tagged release tarballs lives upstream, in the Sarina repo itself, at
`packaging/arch/PKGBUILD` (`pkgname=sarina` there), and is the source of
truth for the systemd unit, sysusers snippet, and env file both PKGBUILDs
install.

## Sarina's role in the distro

Beyond running as a packaged, on-system service (`sarina-service`, from
`packaging/arch/` upstream), the intent is for Sarina to take an active
hand in maintaining Chymaera itself over time — not just be an app that
happens to ship on it:

- **Tool organization**: raw BlackArch packages tend to drop binaries into
  `/usr/bin` with no menu entry or categorization (the exact "installs
  things wherever" problem Kali's curated menus solve). Sarina is meant to
  help generate/maintain `.desktop` entries and Plasma menu categories for
  newly added tools as the curated `blackarch-*` selection evolves, rather
  than that being purely a hand-maintained list here.
- **Keeping the system current, safely**: helping evaluate `pacman -Syu` /
  BlackArch updates for what's safe to apply automatically vs. what needs a
  human look (ABI breaks, config-file conflicts, a tool category that failed
  its last `blackarch_compat` run), with an explicit bias toward secure,
  functional, and efficient over just "newest."

Neither of these exists yet — they're direction, not implementation. As
they take shape they'll live in the Sarina repo itself (`packages/sarina`),
with this repo consuming whatever surface it ends up exposing (a CLI
command, a systemd timer, a Plasma applet, etc. — TBD).

## Open questions / not yet decided

- Whether the hand-picked core is the right size and shape. It is a floor,
  chosen for offline usefulness, not a considered curation — revisit once
  Sarina's install-time selection exists and it is clear what the core has to
  cover on its own.
- Sequencing: the lean ISO assumes Sarina will deliver tools post-install, and
  that capability does not exist yet. Until it does, Chymaera ships less
  tooling than it did as a concept. That is an accepted, temporary cost.
- Calamares: the job sequence, `unpackfs` source and a post-unpack cleanup are
  configured but **have never been run** (see [INSTALLER.md](INSTALLER.md)).
  Still on upstream defaults: branding (`branding.desc`, logo, slideshow),
  partition and user defaults, and the required-disk-space check. Whether to
  package the config as a `chymaera-calamares-config` package or keep it in
  `airootfs` (as now) is open; `airootfs` works because Calamares only runs on
  the live medium.
- Chymaera's own identity on top of the MacTahoe base: logo, a Chymaera
  wallpaper, and a Calamares branding module. The desktop currently looks
  like macOS, not like Chymaera.
- The desktop wallpaper is still Plasma's default. Setting it means writing
  `plasma-org.kde.plasma.desktop-appletsrc`, which also encodes the panel
  layout -- hand-writing a partial one risks shipping a session with no
  taskbar. The safe route is to configure it once in a booted VM and copy the
  resulting file into `airootfs`.
- Branding: ISO/desktop theming, wallpaper, SDDM theme, Plasma look-and-feel
  package — none of this exists yet.
- Concrete shape of Sarina's on-system maintenance role (see above) — CLI
  tool, systemd timer, Plasma applet, or some combination.
