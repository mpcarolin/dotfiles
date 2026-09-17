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
	-- App focus. ctrl+alt+<initial>.
	{ { "ctrl", "alt" }, "G", app = "Ghostty" },
	{ { "ctrl", "alt" }, "O", app = "Obsidian" },

	-- Window management (Hyprland-style). cmd+alt+<vim direction>.
	{ { "cmd", "alt" }, "H", fn = wm.left_half },
	{ { "cmd", "alt" }, "L", fn = wm.right_half },
	{ { "cmd", "alt" }, "K", fn = wm.top_half },
	{ { "cmd", "alt" }, "J", fn = wm.bottom_half },
	{ { "cmd", "alt" }, "M", fn = wm.fullscreen },
	{ { "cmd", "alt" }, "C", fn = wm.center },
	{ { "cmd", "alt" }, "=", fn = wm.increase_padding },
	{ { "cmd", "alt" }, "-", fn = wm.decrease_padding },
}
