# hammerspoon

Keyboard shortcuts, as data. `install.sh` symlinks this directory to
`~/.hammerspoon`, so editing files here *is* editing the live config.

## Where the shortcuts are

| File | Tracked? | What |
|---|---|---|
| `bindings.lua` | **yes** | Cross-machine shortcuts. Shared with the work machine, so nothing here may assume a home-only tool. |
| `bindings.local.lua` | **no — gitignored** | This machine's shortcuts. Where the `theme` bindings live. |
| `bindings.local.lua.template` | yes | Starting point for a new machine: copy to `bindings.local.lua`. |
| `init.lua` | yes | Entry point. Merges the two binding files, then hands them to the dispatcher. |
| `lib/dispatch.lua` | yes | The engine: turns rows into hotkeys, validates them. |

Because `bindings.local.lua` is gitignored, it never shows up in `git status` —
that is deliberate (it is per-machine), but it means **`git status` is not how you
find your own shortcuts**. Read the file.

## Adding a shortcut

Add a row. Never write an `hs.hotkey.bind` call.

```lua
{ { 'cmd', 'shift' }, 'T', cmd = 'theme next' },      -- run a shell command
{ { 'cmd', 'alt' },   'G', app = 'Ghostty' },         -- focus, launching if needed
{ { 'cmd', 'alt' },   'B', app = 'Safari', toggle = true }, -- focus, or hide if frontmost
{ { 'cmd', 'shift' }, 'J', fn = function() … end },   -- arbitrary Lua
```

Exactly one of `cmd` / `app` / `fn` per row. Saving any `.lua` file here reloads
the config automatically; `cmd+alt+ctrl+R` reloads by hand.

## Current bindings

| Key | Action | Defined in |
|---|---|---|
| `cmd+shift+T` | `theme next` | `bindings.local.lua` |
| `cmd+shift+W` | `theme wallpaper next` | `bindings.local.lua` |
| `cmd+alt+G` | focus Ghostty | `bindings.lua` |
| `cmd+alt+O` | focus Obsidian | `bindings.lua` |
| `cmd+alt+ctrl+R` | reload this config | `init.lua` |

## How it behaves

- **A missing tool is skipped, not bound.** `on_path` checks each `cmd`'s
  executable at load; a row for a tool this machine lacks is silently skipped.
  This is what lets `bindings.lua` stay machine-agnostic — no conditionals.
- **Commands run async** via `hs.task`. `hs.execute` blocks Hammerspoon's main
  thread, and a theme switch takes 1-2s, which would freeze other hotkeys.
- **A nonzero exit notifies** with the command's stderr, rather than failing silently.
- **Duplicate hotkeys and malformed rows are reported** in an alert at load —
  the last binding does not quietly win.
- On load you get a brief "N shortcuts" alert.

## Requirements

Hammerspoon needs **Accessibility** permission (System Settings → Privacy &
Security → Accessibility). Without it no hotkey registers.
