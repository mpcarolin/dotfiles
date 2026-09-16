--- Cross-machine shortcuts. This file is tracked and shared with the work
--- machine, so everything here must be safe on BOTH. A row whose tool or app
--- is absent is skipped at load, not bound — so "safe" mostly means "do not
--- assume a home-only path".
---
--- Machine-specific bindings go in `bindings.local.lua` (gitignored), which is
--- merged after this file and can override any row by reusing its hotkey.
---
--- Row format:  { {mods}, 'KEY', cmd = '…' | app = '…' [, toggle = true] | fn = … }

return {
	-- App focus. cmd+alt+<initial>.
	{ { "cmd", "alt" }, "G", app = "Ghostty" },
	{ { "cmd", "alt" }, "O", app = "Obsidian" },
}
