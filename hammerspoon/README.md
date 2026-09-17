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
| `lib/theme.lua` | yes | A popup theme picker, bound as a `choose` row. |

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
{ { 'cmd', 'shift' }, 'P', choose = { … } },          -- popup picker
```

Exactly one of `cmd` / `app` / `fn` / `choose` per row. Saving any `.lua` file
here reloads the config automatically; `cmd+alt+ctrl+R` reloads by hand.

Add `requires = 'exe'` to any row to declare a tool it needs — the row is
skipped on a machine without it. A `cmd` row infers this from the command.

### Popup pickers

`choose` builds an `hs.chooser`: the same Spotlight-style widget Alfred and
Raycast imitate, with type-to-filter, arrow navigation and Enter to pick. No
extra app required.

```lua
{
  { 'cmd', 'shift' }, 'P',
  choose = {
    placeholder = 'Theme',
    items = function()  -- a function is re-run on every open, so the list is live
      return { { text = 'everforest', subText = 'dark' } }
    end,
    onSelect = function(item) … end,  -- not called if the user escapes
  },
  requires = 'theme',
}
```

`lib/theme.lua` is a worked example: it parses `theme list --porcelain` (a
machine-readable format added for exactly this, so the picker never scrapes the
human output) and sorts the active theme to the top.

## Current bindings

| Key | Action | Defined in |
|---|---|---|
| `cmd+shift+P` | popup theme picker | `bindings.local.lua` |
| `cmd+shift+T` | `theme toggle` — cycle favourites | `bindings.local.lua` |
| `cmd+shift+W` | `theme wallpaper next` | `bindings.local.lua` |
| `cmd+alt+G` | focus Ghostty | `bindings.lua` |
| `cmd+alt+O` | focus Obsidian | `bindings.lua` |
| `ctrl+alt+H` | left half of screen | `bindings.lua` |
| `ctrl+alt+L` | right half of screen | `bindings.lua` |
| `ctrl+alt+K` | top half of screen | `bindings.lua` |
| `ctrl+alt+J` | bottom half of screen | `bindings.lua` |
| `ctrl+alt+M` | fullscreen (Hammerspoon-level, not macOS Spaces) | `bindings.lua` |
| `ctrl+alt+C` | center at ~85% of screen size | `bindings.lua` |
| `ctrl+alt+=` | increase window padding | `bindings.lua` |
| `ctrl+alt+-` | decrease window padding | `bindings.lua` |
| `cmd+alt+ctrl+R` | reload this config | `init.lua` |

The half/fullscreen layouts leave a gap at the screen edge and between
adjacent halves, set by `M.padding` (points, starts at 8) in `lib/wm.lua`.
Adjust it live with `ctrl+alt+=` / `ctrl+alt+-` (4pt per press, alerts the
new value); if the focused window is already snapped to one of these
layouts it is reflowed immediately, otherwise the new padding applies to
the next placement.

## How it behaves

- **A missing tool is skipped, not bound.** `on_path` checks each `cmd`'s
  executable at load (or the row's `requires`); a row for a tool this machine
  lacks is silently skipped. This is what lets `bindings.lua` stay
  machine-agnostic — no conditionals.
- **Commands run async** via `hs.task`. `hs.execute` blocks Hammerspoon's main
  thread, and a theme switch takes 1-2s, which would freeze other hotkeys.
- **A nonzero exit notifies** with the command's stderr, rather than failing silently.
- **Duplicate hotkeys and malformed rows are reported** in an alert at load —
  the last binding does not quietly win.
- On load you get a brief "N shortcuts" alert.

## Requirements

Hammerspoon needs **Accessibility** permission (System Settings → Privacy &
Security → Accessibility). Without it no hotkey registers.
