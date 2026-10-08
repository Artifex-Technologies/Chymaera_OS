# Third-party notices

## Omarchy

Parts of the Hyprland session configuration are adapted from
[Omarchy](https://github.com/omacom/omarchy), pinned to tag `v4.0.4`
(`c668141`):

- `profile/airootfs/home/live/.config/hypr/bindings/tiling.lua` — Omarchy's
  `default/hypr/bindings/tiling.lua`, with lines that call Omarchy-only helper
  scripts removed.
- `profile/airootfs/home/live/.config/hypr/modes/omarchy.lua` — values from
  Omarchy's `default/hypr/looknfeel.lua`.
- The structure of `hyprland.lua`, the `o.bind` helper, and
  `profile/airootfs/usr/local/bin/chymaera-desktop-mode` follow Omarchy's
  Hyprland Lua config and its `omarchy-hyprland-toggle` script.

Omarchy is released under the MIT License:

```
Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
