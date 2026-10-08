# Chymaera OS

Chymaera OS is an Arch-based distribution built for security research and
penetration testing, combining:

- **[Arch Linux](https://archlinux.org/)** as the rolling-release base
- **[BlackArch](https://github.com/BlackArch/blackarch)** tooling, available as
  a repo but not bulk-installed: the ISO ships a small offline-usable core and
  Sarina installs the rest on demand
- **[Omarchy](https://github.com/omacom/omarchy)** as the model for the
  desktop: a keyboard-driven Hyprland session with Omarchy's keybindings, plus
  a second "stealth" look that imitates a macOS desktop, switched in place with
  `SUPER + F12`. Omarchy is an upstream we follow, not a fork: see
  [Built on Omarchy](#built-on-omarchy)
- **[KDE Plasma](https://github.com/kde/plasma-desktop)** as the current default
  session and the fallback one, themed macOS-like (MacTahoe, light and dark)
  with a conventional bottom taskbar rather than a dock
- **[Sarina](https://github.com/Artifex-Technologies/Sarina)**, an AI agent integrated
  directly into the OS — for choosing and organising tooling, and for making
  sense of scan and capture output in place

The goal is Kali-style organization, documentation, and out-of-the-box UX for
security tooling, on top of Arch's package freshness and BlackArch's tool
catalog — built and versioned in the open on GitHub, which BlackArch and Kali
do not do.

## Why another security distro?

Kali does a lot right: curated tool menus, consistent documentation, a
predictable release/support cadence. But Kali isn't developed in the open on
GitHub, and BlackArch (which *is* on GitHub) ships its full tool catalog by
default, which can make the base system less stable for daily use. Chymaera
aims to sit between them: an openly developed, Arch-based system with a
deliberately small default tool set, a polished desktop (Hyprland, with KDE
Plasma as the fallback session), and an AI agent built in to help with recon, scripting, analysis, and general system
tasks.

## How tooling is delivered

The ISO ships **~27 hand-picked security tools**, not BlackArch's category
groups. Baking in the categories was tried and abandoned: it pulled in
several thousand packages nobody had chosen, along with unresolvable
32-bit dependencies and provider conflicts that made the ISO too large to
build in CI. The reasoning is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

What ships covers recon, traffic capture, wireless, password attacks, web
application testing, exploitation, reverse engineering and forensics — chosen
so that **the live session is useful with no network at all.** Air-gapped
client sites and offline forensics are where a live USB earns its keep, and
they are the one thing an install-on-demand model cannot serve.

Everything past that core is Sarina's job: asking what the machine is for,
installing accordingly, and generating the `.desktop` entries and Plasma menu
categories that BlackArch packages don't ship. Those capabilities are still
being built.

## Built on Omarchy

[Omarchy](https://github.com/omacom/omarchy) (MIT, by David Heinemeier Hansson)
is the reference for Chymaera's desktop, and where its packages fit they are
consumed as-is rather than copied, so its updates keep flowing. What is in the
tree today:

- A Hyprland session, installed beside Plasma and selectable at the login
  screen, using Omarchy's window and workspace keybindings verbatim
  ([THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) has the attribution and
  licence).
- Two looks in one session, toggled with `SUPER + F12` and no logout: the
  default tiling look, and a floating, rounded macOS-style "stealth" look with a
  menu bar and dock. Boot-tested in a VM.

Planned, not built: Omarchy's Quickshell shell, which brings its screensaver,
theme system and third-party lock screens, and Omarchy's agents panel showing
Sarina's usage beside Claude Code and the other agents. Chymaera keeps its own
live ISO, installer, system identity and boot configuration rather than taking
Omarchy's `omarchy-settings` package, which overwrites `/etc/os-release` on
every upgrade.

Chymaera does not use an AUR helper. AUR-only software we need (Calamares) is
vendored as a PKGBUILD and built into Chymaera's own repo. Omarchy installs AUR
packages with `yay`; whether Chymaera adopts that is undecided.

The design, measurements and everything still unverified are in
[docs/DESKTOP.md](docs/DESKTOP.md).

## Repository layout

```
Chymaera_OS/
├── profile/                  # archiso profile used to build the live/install ISO
│   ├── profiledef.sh         # ISO metadata (name, label, boot modes, etc.)
│   ├── packages.x86_64       # package list installed into the ISO/target system
│   ├── pacman.conf           # repo config: core/extra + [blackarch] + [chymaera]
│   └── airootfs/             # files overlaid onto the live system's root (incl. etc/calamares/)
├── packages/
│   ├── sarina/                # git submodule: Sarina source (private repo)
│   └── pkgbuilds/
│       ├── sarina-git/        # PKGBUILD building packages/sarina locally
│       └── calamares/         # vendored AUR PKGBUILD (graphical installer)
├── repo/                     # local pacman repo built from pkgbuilds (gitignored contents)
├── docs/                     # ARCHITECTURE.md, DESKTOP.md (Hyprland/Omarchy), INSTALLER.md (Calamares)
├── scripts/                  # Build/dev helper scripts
├── CLAUDE.md                 # Guidance for AI agents working in this repo
└── .github/workflows/        # CI: build (and eventually publish) the ISO
```

## Building the ISO

Building requires an Arch Linux (or Arch container) environment with
`archiso` installed — it will not run on Windows/macOS directly. See
[scripts/build.sh](scripts/build.sh) and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

```bash
sudo pacman -S --needed archiso base-devel git
git clone --recurse-submodules https://github.com/Artifex-Technologies/Chymaera_OS.git
cd Chymaera_OS

# 1. Build local packages (Sarina, Calamares) as a regular user (makepkg refuses to run as root)
./scripts/build-local-packages.sh

# 2. Build the ISO as root (mkarchiso requires it)
sudo ./scripts/build.sh
```

The resulting ISO is written to `out/`. Set `CHYMAERA_WORK_DIR` and
`CHYMAERA_OUT_DIR` to put the build tree and output on a different filesystem
(CI uses this to reach a larger disk).

### Building and testing under WSL

Development happens on Windows, so WSL2 with an Arch distribution is the
normal way to build and boot-test. Two things matter:

- **Clone into the WSL filesystem** (`~/`), never `/mnt/c`. Windows drives
  don't preserve the symlinks in `profile/airootfs/` or Unix permissions, and
  a build tree there would also try to sync to OneDrive.
- **`makepkg` refuses to run as root**, so create an ordinary user for stage 1
  even though WSL logs you in as root by default.

## Status

Early, but building. The archiso profile, BlackArch repo wiring, KDE Plasma
package set, Calamares packaging and Sarina packaging are in place, and the
package set resolves cleanly (837 packages, no conflicts). The Hyprland session
is boot-tested in a VM.

The installer is configured but **has never been run**: Calamares copies the live
squashfs to disk instead of rebuilding the system, which is meant to make it fast
and work offline ([docs/INSTALLER.md](docs/INSTALLER.md)). Until someone boots
the ISO and installs it, treat installation as unproven; the live session is the
tested part. Install speed and the larger ISO that zstd compression produces have
not been measured.

Not yet done: the agent-assisted install flow, tool categorisation, Chymaera
branding (including the installer's), Omarchy's Quickshell shell, and testing on
real GPU hardware. Expect rapid changes.

## Sarina

[`packages/sarina`](packages/sarina) is a git submodule pointing at
[Sarina](https://github.com/Artifex-Technologies/Sarina) (private, formerly
Chymaera Code Agent) — a local-first, Python reimplementation of the Claude
Code agent architecture, runnable against local open models. It already
ships its own Arch packaging (`packaging/arch/`) and a
[`blackarch_compat`](https://github.com/Artifex-Technologies/Sarina/tree/main/blackarch_compat)
harness built specifically for *this* distro: it installs BlackArch's
`blackarch-*` pacman categories one at a time in disposable Docker containers
to catch install-time breakage. Now that the ISO no longer bakes in those
categories, that harness becomes the safety check behind Sarina's own
install-time suggestions — it should know a category installs cleanly before
offering it.

Sarina's intended role in the running system, none of which exists yet:

- **Guided install** — ask what the machine is for and install tooling to
  match, instead of shipping a guess.
- **Organisation** — generate `.desktop` entries and Plasma menu categories
  for tools that drop bare binaries into `/usr/bin`, which is the problem
  Kali's curated menus solve by hand.
- **Analysis** — read scan, capture and log output in place and summarise it,
  so triage doesn't mean scrolling raw tool output.
- **Maintenance** — evaluate `pacman -Syu` and BlackArch updates for what is
  safe to apply automatically versus what needs a human look.

To pull in the latest Sarina code:

```bash
./scripts/update-sarina.sh   # advances packages/sarina, stages the pointer bump
```

## References

- [Calamares](https://codeberg.org/Calamares/calamares) — the primary
  graphical, live-session installer (AUR-only; vendored at
  `packages/pkgbuilds/calamares`, configured in
  `profile/airootfs/etc/calamares/`). GitHub's copy is archived; Codeberg is
  where development moved.
- [archinstall](https://github.com/archlinux/archinstall) — Arch's guided
  CLI installer; kept available as a scripted alternative to Calamares.
- [archiso](https://github.com/archlinux/archiso) — the tool used to build
  this project's live/install ISO (see `profile/`).
- [archlinux/devtools](https://github.com/archlinux/devtools) — official
  clean-chroot package build/test tooling; reference point for isolating
  package builds here.
- [BlackArch](https://github.com/BlackArch/blackarch) — source of the
  security tooling repo and package catalog.
- [KDE Plasma Desktop](https://github.com/kde/plasma-desktop) — the primary
  desktop environment (installed via the `plasma-meta` group).
- [Sarina](https://github.com/Artifex-Technologies/Sarina) — the AI agent
  integrated into the OS (private repo, submodule at `packages/sarina`).
- [Omarchy](https://github.com/omacom/omarchy) — the Hyprland desktop this
  project's session, keybindings and look-switching are modelled on (MIT). Its
  install scripts were read as a reference for the installer; nothing from them
  is used yet ([docs/INSTALLER.md](docs/INSTALLER.md)).
- [Try Omarchy for Windows](https://github.com/omacom/try-omarchy-windows) —
  runs Omarchy in QEMU on the Windows Hypervisor Platform from a prebuilt
  image. A possible route to boot-testing Chymaera's ISO from Windows without
  WSL; not evaluated for that yet.

## License

[GPL-3.0](LICENSE), matching the convention used by BlackArch and most
security-tooling distributions.