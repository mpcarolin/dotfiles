--- Cross-machine shortcuts. This file is tracked and shared with the work
--- machine, so everything here must be safe on BOTH. A row whose tool or app
--- is absent is skipped at load, not bound — so "safe" mostly means "do not
--- assume a home-only path".
---
--- Machine-specific bindings go in `bindings.local.lua` (gitignored), which is
--- merged after this file and can override any row by reusing its hotkey.
---
--- Row format:  { {mods}, 'KEY', cmd = '…' | app = '…' [, toggle = true] | fn = … }

local wm = require("lib.wm")

return {
	-- App focus. cmd+alt+<initial>.
	{ { "cmd", "alt" }, "G", app = "Ghostty" },
	{ { "cmd", "alt" }, "O", app = "Obsidian" },

	-- Window management (Hyprland-style). ctrl+alt+<vim direction>.
	{ { "ctrl", "alt" }, "H", fn = wm.left_half },
	{ { "ctrl", "alt" }, "L", fn = wm.right_half },
	{ { "ctrl", "alt" }, "K", fn = wm.top_half },
	{ { "ctrl", "alt" }, "J", fn = wm.bottom_half },
	{ { "ctrl", "alt" }, "M", fn = wm.fullscreen },
	{ { "ctrl", "alt" }, "C", fn = wm.center },
	{ { "ctrl", "alt" }, "=", fn = wm.increase_padding },
	{ { "ctrl", "alt" }, "-", fn = wm.decrease_padding },
}
