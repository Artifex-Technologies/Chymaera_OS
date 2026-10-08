# Desktop: one Hyprland session, two looks

Chymaera's desktop is [Omarchy](https://github.com/omacom/omarchy)-derived
Hyprland with a second look that imitates a macOS/MacTahoe desktop, switched
with **SUPER + F12** and no logout. Plasma stays installed as a real fallback
session. This document records what Omarchy actually is, what we took from it,
what we did not, and what is not verified yet.

## Status

| Piece | State |
| --- | --- |
| Hyprland session installable and selectable at the SDDM greeter | Built and **boot-tested in QEMU/KVM** (2026-09-26): starts, bar loads, `SUPER + RETURN` opens a terminal |
| Two looks + `chymaera-desktop-mode` toggle | **Verified in QEMU**: `SUPER + F12` flips both ways; after four toggles there is still one bar and one dock. Two bugs found and fixed (below) |
| Hyprland as the autologin default | **Not done** — Plasma still autologins |
| Omarchy's Quickshell shell (real bar, menu, lock, notifications, screensaver) | **Wanted, not adopted**; Waybar stand-in for now. Route chosen, see "Adopting Omarchy's Quickshell shell" |
| Omarchy theme system (`colors.toml` + templates) | Comes with the shell above |
| MacTahoe GTK theme | Not packaged (icons, cursor, Kvantum are) |
| Installed system gets the desktop config | Written (`chymaera-install-cleanup` copies the live user's `.config` into `/etc/skel`); **never run**, see [INSTALLER.md](INSTALLER.md) |
| Proton VPN, Sarina crash diagnosis | Contracts only; see below |
| Tailscale / Headscale | Optional, off by default; see below |

Testing so far is QEMU/KVM with software rendering, driven by keystrokes over
QMP and read back as screenshots. **Not yet tried on real GPU hardware**, and
the ISO build has only been run in WSL, not in CI.

Static checks: the package list resolves against live Arch repos (197
requested, no provider menus, no conflicts), every Lua file parses under `luac`,
both Waybar configs parse as JSON, and `chymaera-desktop-mode` passes `bash -n`.

**What the boot test caught that the static checks and a stubbed script test
did not** (all fixed):

- Waybar formats time with `fmt`, which rejects GNU flags like `%-d` and `%-I`;
  the clock module silently vanished from the stealth bar.
- `pkill -x nwg-dock-hyprland` never matches: the kernel truncates process
  names to 15 characters and the name is 18. The old dock was never killed.
- `nwg-dock-hyprland -s` takes a filename *relative to its config directory*;
  passing an absolute path made it fatal at startup, so there was no dock.

## What Omarchy is (as of v4.0.4)

Read from the repo at tag `v4.0.4`; the latest at the time of writing.

- **Hyprland with a Lua config.** Hyprland deprecated hyprlang in 0.55 in favour
  of `hyprland.lua`; Arch's `hyprland` is 0.56.2. Omarchy's config is
  `hl.config`, `hl.bind`, `hl.dsp.*`, `hl.window_rule` calls.
- **A Quickshell desktop shell.** Bar, menu, notifications, lock screen, OSDs
  and panels are QML plugins in one long-lived Quickshell process
  (`shell/plugins/`). It is not Waybar or Walker any more, and `walker` is not
  in Arch's repos.
- **Two packages, built in a separate repo (`omarchy-pkgs`):** `omarchy`
  (binaries, themes, the shell) and `omarchy-settings` (`/etc` drop-ins,
  bootloader, snapshot and mkinitcpio config). They are tightly coupled to
  Omarchy's own installer, Limine and Snapper. Adopting them wholesale would
  replace parts of Chymaera that archiso and Calamares own, so we do not.
- **The `[omarchy]` pacman repo:** `https://pkgs.omarchy.org/stable/$arch`,
  `SigLevel = Required DatabaseOptional`, signing key
  `40DFB630FF42BCFFB047046CF0134EE680CAC571`. Channels: `stable`, `rc`, `edge`.
  248 packages, read from the repo database: the `omarchy` and
  `omarchy-settings` packages, `quickshell-git`, `ttfx`, `walker` and the
  `elephant-*` backend, `owe`, `hyprshade`, `wayfreeze`, `umu-launcher`,
  `heroic-games-launcher-bin`, `sunshine`, `nordvpn-bin`, several agent CLIs
  and Omarchy's own kernels (`linux-omarchy*`), plus many apps. No Proton VPN.
- **Theming:** a theme is a `colors.toml` plus templates in `default/themed/`
  rendered into each app's config by `omarchy-theme-set`.
- **Toggles:** a toggle copies a small Lua file into
  `~/.local/state/omarchy/toggles/hypr/` and runs `hyprctl reload`. This is the
  mechanism `chymaera-desktop-mode` copies.
- **"AI":** Omarchy ships launchers for coding-agent CLIs. The feature closest
  to "AI troubleshooting a game" is **crash diagnosis**: a systemd-coredump
  watcher raises a "Process crashed" notification; clicking it hands the crash
  to the default agent along with a `diagnose-crash` skill. See below.

## Design

### One session, two looks

`~/.config/hypr/hyprland.lua` sets up everything common (environment, input,
keybindings, session services), then loads `modes/omarchy.lua` or
`modes/stealth.lua` depending on one word in
`~/.local/state/chymaera/desktop-mode`. The word is checked against a fixed
list, so the state file can never steer `dofile()` at an arbitrary path.

`chymaera-desktop-mode toggle` writes the word, runs `hyprctl reload`, then
restarts the bar and dock and rewrites GTK icon and Kvantum settings.

| | `omarchy` (default) | `stealth` |
| --- | --- | --- |
| Windows | tiled, 5px gaps, 2px gradient border | floating, no gaps, 12px rounded, shadow, blur |
| Bar | Waybar: workspaces, clock, status | Waybar: menu bar (active app left, status + clock right) |
| Dock | none | `nwg-dock-hyprland`, translucent shelf |
| GTK icons / Kvantum | Adwaita / KvAdaptaDark | MacTahoe-dark / MacTahoeDark |

Keybindings are identical in both, so nothing has to be relearned when
switching. That includes `SUPER + T` (float/tile a window), which is the manual
fix for windows that were already open when the look changed.

**Known limits.** Stealth is an imitation of macOS, not Plasma; someone who
clicks around will notice. The bar uses text labels (`wifi`, `vol`) because no
icon font is guaranteed to be present. Windows already open at the moment of the
switch keep their old float/tile state (observed: a window floated in stealth
stays floating after switching back). There is no lock screen: the live
account has no password, so a lock screen would have nothing to unlock with.

### Adopting Omarchy's Quickshell shell (the real target)

Waybar is a stopgap. What makes Omarchy feel like Omarchy — the bar, menu,
notifications, lock screen, screensaver and the theme system — is its Quickshell
shell, and that is what we want. Third-party lock screens such as
[omarchy-lock-explorer](https://github.com/SirJul1337/omarchy-lock-explorer)
(MIT, 60+ designs) are also Omarchy-4 shell plugins: they replace the built-in
`omarchy.lock` service and are driven by `omarchy-shell lock ...`, so they need
the real shell, not a look-alike.

Measured against the v4.0.4 source and the live `[omarchy]` repo database:

- **The shell calls 98 distinct `omarchy-*` helper commands; 77 are scripts in
  the `omarchy` package's `bin/`.** So adopting the shell means adopting that
  `bin/`, not just `shell/*.qml`.
- **`omarchy` (4.0.4-1, 121 MB installed, 442 binaries) has no install
  scriptlet** (checked in the package): it is inert files. Its hard dependencies
  are `omarchy-keyring`, `omarchy-settings=4.0.4` (an *exact* version),
  `hyprland`, `quickshell`, `uwsm`, `sddm`, `xdg-desktop-portal-hyprland`,
  `wireplumber`, `pipewire`, `gnome-keyring`, `gum`, `jq`, `git`, `perl`,
  `fakeroot`, `pacman-contrib`, a Nerd font, and **`limine`,
  `limine-mkinitcpio-hook`, `limine-snapper-sync` and `snapper`**.
- **`omarchy-settings` (4.0.4-1) is the dangerous one, and it does have an
  install scriptlet.** On *every install and every upgrade* it overwrites
  `/etc/os-release`, `/etc/nsswitch.conf`, `/etc/security/faillock.conf`,
  `/etc/plymouth/plymouthd.conf` and `/etc/skel/.bashrc` (its own comments call
  this "intentionally destructive"). Installed as-is, each `pacman -Syu` would
  reset Chymaera's identity to Omarchy's. It also ships `/etc` drop-ins for
  mkinitcpio hooks, SDDM, sudoers, sysctl and logind, plus `limine-entry-tool`
  and snapper templates. A stray mkinitcpio hook is how an ISO builds fine and
  then panics at boot (see CLAUDE.md), and its SDDM config would fight our
  autologin.
- **`ttfx`** (0.3.2-1), which the screensaver and several lock designs need, is
  only in `[omarchy]`. The Omarchy `quickshell-git` build (0.3.0.r20) is also
  there; Arch `extra` has `quickshell` 0.3.1. Whether the shell needs the git
  build is unknown until it is run.
- The screensaver needs `ttfx` plus one of Alacritty, Foot, Ghostty or Kitty;
  we ship Foot.

**Route (revised): consume Omarchy's real packages, and replace only
`omarchy-settings`.** An earlier draft of this document recommended vendoring
`omarchy` from source. That forfeits Omarchy's updates: 442 scripts and a
migration system would drift from a frozen copy, and the trust in their public
research and releases is the reason to follow them. Arch has a standard tool
for this: a package that `provides=('omarchy-settings=X.Y.Z')` satisfies the
dependency in place of the real one. So:

- Install the real `omarchy`, `omarchy-keyring`, `ttfx`, `quickshell-git` etc.
  from `[omarchy]`.
- Ship `chymaera-settings`, which provides `omarchy-settings=<same version>`.
  It is built *from the real `omarchy-settings` tarball at that version*, keeping
  the parts Omarchy's scripts expect (the `/etc/skel` config seeds, `/usr/share/omarchy`
  defaults, user units) and dropping the install scriptlet, the identity
  overwrites, the mkinitcpio, SDDM, Limine and snapper files.
- Because the dependency is an exact version, `chymaera-settings` must be
  re-cut on every Omarchy release. That is mechanical and a good job for CI, or
  for Sarina proposing the bump (see "Sarina contracts").
- Limine and Snapper still install (hard dependencies) but stay unconfigured.
  Shadowing them with empty providers is possible if their size matters.

**Untested.** Nothing here has been installed on an image yet. The open
questions a build must answer: whether `omarchy`'s scripts run without the
files we drop, whether `quickshell` from `extra` is enough, and whether the
`provides` shim resolves cleanly in pacstrap.

This needs `[omarchy]` in the image's `pacman.conf`, so the baked-in set depends
on Omarchy's signing key at *build* time. **Decided by the maintainer:
trusted**, on the grounds that Omarchy's research, findings and updates are
fully public. The key fingerprint is still verified rather than assumed; see
"The `[omarchy]` repo".

### Phasing

1. **This change.** Hyprland is installed and selectable; Plasma is still the
   autologin session.
2. **Boot-test in a VM** (or read the CI ISO). Confirm Hyprland starts, the
   bar and dock appear, and SUPER + F12 flips the look.
3. **Make Hyprland the default.** In
   `profile/airootfs/etc/sddm.conf.d/autologin.conf`, change `Session=plasma` to
   `Session=hyprland-uwsm`. `hyprland` ships `hyprland-uwsm.desktop` (checked
   against Arch's file list for the package). The live-session accommodations —
   passwordless sudo, polkit rule, no lock screen — already cover it.
4. **Adopt Omarchy's Quickshell shell** by installing the real `omarchy`
   package from `[omarchy]` and shimming `omarchy-settings` with
   `chymaera-settings` (see "Route (revised)" above; the earlier plan to vendor
   from source was dropped). That brings its theme system, screensaver and
   plugin support, and makes third-party lock screens installable. Waybar and
   the dock remain only for the stealth look until the shell has a stealth
   layout.
5. **Package the MacTahoe GTK theme** so stealth mode covers GTK apps, not just
   icons and Kvantum.

### Omarchy's installer and Windows trial image

Omarchy's own install flow was read as a reference for Chymaera's installer and
is **not** adopted: it is tied to Omarchy's bootloader, snapshot and package
layout, and Omarchy's repo does not contain the base-system install that makes
it quick. What was read, and what Chymaera borrowed or might, is in
[INSTALLER.md](INSTALLER.md#what-we-took-from-omarchy). Separately,
[`try-omarchy-windows`](https://github.com/omacom/try-omarchy-windows) (MIT)
boots a prebuilt Omarchy image in QEMU on the Windows Hypervisor Platform; it
may offer a way to boot-test Chymaera's ISO from Windows without WSL, which has
not been checked.

## The `[omarchy]` repo

It is **not** enabled on the ISO or in the installed system yet. It is a
third-party repository whose signing key can push root-installed packages onto a
security distro, the same kind of trust decision as `[blackarch]`. The
maintainer has decided to trust it. When enabled, it should be:

- present in the image's `pacman.conf` (it supplies the shell and `ttfx`);
- pinned to the `stable` channel (`https://pkgs.omarchy.org/stable/$arch`); an
  older `https://pkgs.omarchy.org/$arch` path serves only `omarchy-keyring`,
  which is a documented pitfall;
- fetched with the key fingerprint verified against
  `40DFB630FF42BCFFB047046CF0134EE680CAC571` before `pacman-key --lsign-key`.

Do not install `omarchy-settings` or the `linux-omarchy*` kernels from it; see
above. Apps and utilities are fine.

## Sarina contracts

Neither exists yet. They are recorded in `CLAUDE.md` as things Chymaera needs
from Sarina.

### Crash diagnosis

Omarchy's design, which we should copy: a `systemd-coredump` watcher, a
notification carrying the PID/binary/signal, and a hand-off to the agent with a
skill that says how to investigate. In Chymaera the agent is Sarina. For games
the useful evidence is the coredump, the Proton/Wine log, `journalctl`, GPU
driver state, and the launch options. Sarina should propose fixes, not apply
them unattended.

### Sarina as manager of all agents

Omarchy does not bundle a model or an agent of its own. It ships launchers for
about thirteen third-party agent CLIs (Claude Code, Codex, OpenCode, Hermes,
Crush, Cursor CLI and others), one **agents panel** in the bar, the crash
hand-off described above, and an "Omarchy skill" that teaches whichever agent is
running how to tailor the system (symlinked into `~/.claude/skills`,
`~/.codex/skills` and similar). It recommends LM Studio or Ollama for local
models.

The panel is a pure display over JSON files. Each agent has one record in
`~/.local/state/omarchy/agents/usage/<agent>.json` (`id`, `name`, `updatedAt`,
limits, per-day and per-model token stats), and *anything* that writes such a
file gets a tab; a collector is just a script printing that record. That makes
three integration points for Sarina, in increasing order of power and risk:

1. **Sarina appears in the panel.** She writes her own `sarina.json`. No
   Omarchy code changes, nothing to patch on update.
2. **Sarina reads every agent's record**, which Omarchy has already normalised
   across Claude, Codex and the rest. She gets a single view of limits and spend
   for free, and can warn or route work to whichever agent has headroom.
3. **Sarina launches and supervises other agents.** This is the "manager"
   role, and the risky one: Omarchy starts agents in their auto-approve modes,
   so an agent launched by a prompt-injected Sarina runs with no human in the
   loop. It should therefore be proposal-first with human approval, and Chymaera
   Sentry, which already watches Sarina, is the natural watcher for it.

Built in that order, on the Sarina side, as `sarina fleet-usage` (1),
`fleet-status [--suggest]` (2) and `fleet-launch` (3):

- **Verified end to end** in the WSL Arch host: Omarchy's own
  `omarchy-agent-usage-update` (v4.0.4, unmodified) ran the collector wrapper and
  wrote a correct `sarina.json`, and `fleet-status` then read it alongside a
  Claude-shaped record and computed headroom. 55 new offline tests.
- **Not verified:** that the panel *draws* Sarina's tab. The record matches the
  fields the panel's QML reads, but that was read from source. It needs the real
  shell, which the image does not ship yet.
- **The launcher is deliberately different from Omarchy's.** It has no way to add
  an auto-approve flag, needs a human `y` (or `--yes`), refuses a prompt that
  changed after the proposal, and audits every attempt to
  `~/.local/state/sarina/agent-launch.jsonl` for Sentry (prompt stored as a hash
  and a 60-character preview). It is a CLI command only, **not a tool the model
  can call**, and a test enforces that.
- **Other agents' records are untrusted input.** Control and bidi characters are
  stripped, text truncated, ids and numbers validated.
- `crush` and `openclaw` are not launchable, for stated reasons.

Still worth doing: have Sarina load the Omarchy skill, so she can tailor the
desktop the same way the other agents can.

### Proton VPN

Correction to an earlier claim: **`proton-vpn-gtk-app` is in Arch's official
`extra` repo** (4.18.1 when checked; 4.18.2 in `extra-testing`), not only the
AUR. Proton does not officially support Arch, but pacman now delivers updates
the normal signed way, which gives the "talk to the repo and keep updating"
behaviour without any packaging on our side. It needs NetworkManager and a
keyring (gnome-keyring or kwallet).

- **Install on demand, not baked in.** It needs an account, so it does not
  serve the offline-core rationale. Sarina installs it when asked. Only
  `wireguard-tools` is on the ISO.
- **Kill switch belongs outside Sarina.** If the VPN must fail closed, that rule
  lives in nftables (or the app's own NetworkManager kill switch), so a crashed
  or prompt-injected agent cannot leave it open. Sarina may *propose* changes to
  network config; a human approves them, and Chymaera Sentry is the natural
  watcher for that surface.
- **Adapting to updates** means Sarina reading the package's changelog and
  version delta after `pacman -Syu` and flagging what changed for the VPN
  (NetworkManager connection names, kill-switch behaviour). Known past breakage:
  Arch forum reports of connection errors after specific app versions.
- **Tailscale and Headscale are a different tool, kept as an option.** They
  build a private mesh between *your own* devices over WireGuard; they do not
  route traffic out through Proton. Useful for connecting a Chymaera box to a
  team or a Flipper rig. Both are in Arch `extra` (`tailscale` 1.102.4,
  `headscale` 0.29.4), so there is nothing to package. Tailscale's coordination
  server is a hosted service; Headscale is the self-hosted replacement for it,
  which is where the cost trade-off you mentioned lives. Neither is installed
  or enabled; Sarina installs them on request.
- **A VPN that hides the source address can conflict with scoped engagements**
  and client allow-lists, so it should be a toggle, not always on.
