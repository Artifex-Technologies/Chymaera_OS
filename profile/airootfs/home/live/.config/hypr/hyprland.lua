-- Chymaera Hyprland session.
--
-- Structure and key layout follow Omarchy (MIT, Copyright (c) David Heinemeier
-- Hansson; see THIRD_PARTY_NOTICES.md). Config is Lua because Hyprland has
-- deprecated hyprlang since 0.55 -- see docs/DESKTOP.md.
--
-- Two looks share this one session and switch in place, with no logout:
--   omarchy  the tiling desktop (default)
--   stealth  a floating, macOS-style desktop that draws no attention
-- Toggle with SUPER + F12, or `chymaera-desktop-mode`. The choice lives in
-- ~/.local/state/chymaera/desktop-mode.

local home = os.getenv("HOME")
local config_dir = home .. "/.config/hypr"

-- Same shape as Omarchy's o.bind: a string dispatcher runs as a command.
o = o or {}
function o.bind(keys, description, dispatcher, options)
  local opts = options or {}
  if description then
    opts.description = description
  end
  if type(dispatcher) == "string" then
    dispatcher = hl.dsp.exec_cmd(dispatcher)
  end
  hl.bind(keys, dispatcher, opts)
end

-- Environment. Wayland everywhere; Qt apps (Dolphin, Kate, ...) use Kvantum so
-- they carry the MacTahoe style in either mode.
hl.env("XCURSOR_SIZE", "24")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
  },

  general = {
    layout = "dwindle",
    allow_tearing = false,
  },

  dwindle = {
    preserve_split = true,
    force_split = 2,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    focus_on_activate = true,
  },

  cursor = {
    hide_on_key_press = true,
  },
})

-- Applications and shell. There is deliberately no lock-screen binding: the live
-- account has no password, so a lock screen would have nothing to unlock with.
o.bind("SUPER + RETURN", "Terminal", "uwsm-app -- foot")
o.bind("SUPER + SHIFT + RETURN", "Browser", "uwsm-app -- firefox")
o.bind("SUPER + SHIFT + B", "Browser", "uwsm-app -- firefox")
o.bind("SUPER + SHIFT + F", "File manager", "uwsm-app -- dolphin")
o.bind("SUPER + SHIFT + N", "Editor", "uwsm-app -- kate")
o.bind("SUPER + SPACE", "Launcher", "fuzzel")

-- The stealth toggle. F12 is unused by Omarchy's defaults, so it cannot shadow
-- a binding you already know.
o.bind("SUPER + F12", "Toggle stealth desktop", "chymaera-desktop-mode toggle")

-- Screenshots, clipboard, media.
o.bind("PRINT", "Screenshot region", "grim -g \"$(slurp)\" - | wl-copy")
o.bind("SUPER + CTRL + V", "Clipboard history", "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")
o.bind("XF86AudioRaiseVolume", "Volume up", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", { locked = true })
o.bind("XF86MonBrightnessUp", "Brightness up", "brightnessctl set 5%+", { locked = true, repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", "brightnessctl set 5%-", { locked = true, repeating = true })
o.bind("XF86AudioPlay", "Play / pause", "playerctl play-pause", { locked = true })
o.bind("XF86AudioNext", "Next track", "playerctl next", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "playerctl previous", { locked = true })

dofile(config_dir .. "/bindings/tiling.lua")

-- Session services. The bar and dock are started by chymaera-desktop-mode so
-- that they always match the current look.
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("uwsm-app -- hyprpolkitagent")
  hl.exec_cmd("uwsm-app -- mako")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("chymaera-desktop-mode apply")
end)

-- Load the current look. The value is checked against a fixed list, so the
-- state file can never steer dofile() at an arbitrary path.
local mode = "omarchy"
local state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
local state_file = io.open(state_home .. "/chymaera/desktop-mode", "r")
if state_file then
  local value = state_file:read("*l")
  state_file:close()
  if value == "stealth" then
    mode = "stealth"
  end
end
dofile(config_dir .. "/modes/" .. mode .. ".lua")
