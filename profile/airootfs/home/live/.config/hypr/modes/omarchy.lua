-- The default look: tiling, square, keyboard-first. Values match Omarchy's
-- default/hypr/looknfeel.lua (MIT, Copyright (c) David Heinemeier Hansson) at
-- tag v4.0.4, minus the animation curves, which can come along with a real
-- theme system later.

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
      inactive_border = "rgba(595959aa)",
    },
    resize_on_border = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 0,
    shadow = { enabled = false },
    blur = { enabled = false },
  },

  animations = {
    enabled = true,
  },
})
