-- The stealth look: a floating, rounded, translucent desktop with a top menu
-- bar and a dock, meant to read as an ordinary macOS-style machine from across
-- a room. The bar and dock come from chymaera-desktop-mode; this file is the
-- compositor half.
--
-- Windows float instead of tile. Windows already open when you switch may keep
-- their tiled state until reopened; SUPER + T floats or tiles one by hand. The
-- keybindings are otherwise unchanged from the default look.

hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
    layout = "dwindle",
  },

  decoration = {
    rounding = 12,
    shadow = {
      enabled = true,
      range = 24,
      render_power = 3,
      color = "rgba(00000055)",
    },
    blur = {
      enabled = true,
      size = 8,
      passes = 2,
    },
  },

  animations = {
    enabled = true,
  },
})

hl.window_rule({ match = { class = ".*" }, float = true })
