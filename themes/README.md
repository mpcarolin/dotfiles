# themes

One directory per theme. The directory name **is** the theme name — the argument you
pass to `theme set <name>`.

Each holds a single `theme.env`: flat `KEY="value"` pairs, sourced by `bin/theme`.
Deliberately not JSON/YAML — `jq` and `yq` are not installed on this machine, and five
keys do not justify a parser dependency.

## The five keys

| Key | Meaning |
|---|---|
| `GHOSTTY_THEME` | A theme name ghostty can resolve — either one of its ~396 built-ins (`ghostty +list-themes`) or a file in `ghostty/themes/`. Written to the gitignored `ghostty/theme.conf`. |
| `NVIM_COLORSCHEME` | Passed to `:colorscheme`. The plugin providing it must already be installed. |
| `NVIM_BACKGROUND` | `dark` or `light` — sets `vim.o.background`, which is what most modern colorscheme plugins branch on. |
| `NVIM_VARIANT` | Family-specific variant. Consumed only by everforest (`soft` \| `medium` \| `hard`); for other families it records the variant name for readability and is otherwise inert. |
| `WALLPAPER_DIR` | Directory under `wallpapers/` to pick a random image from. Several themes may share one (`light`, `neutral`). Falls back to `wallpapers/neutral/` if missing or empty. |

All five are required and must be non-empty; `bin/theme` refuses a manifest that omits one.

## Adding a theme

1. `mkdir themes/<name>` and write a `theme.env` with all five keys.
2. Make sure ghostty can resolve `GHOSTTY_THEME` — check `ghostty +list-themes`, or
   hand-author a file in `ghostty/themes/` (see `everforest-light-medium`, whose palette
   was lifted from the everforest-nvim plugin).
3. Make sure the nvim colorscheme plugin is installed. **Installing it is your job in a
   live `nvim`** — never a `:Lazy` command from a script or an agent.
4. Point `WALLPAPER_DIR` at an existing directory in the wallpapers submodule
   (`light` for light themes, `neutral` for dark ones), or `mkdir wallpapers/<name>`
   and drop in images that genuinely only suit this theme.
5. `theme set <name>`.

## What is intentionally *not* here

No hex palettes, accent colors, preview images, or editor/icon configs. Ghostty themes
and nvim plugins already own their colors; duplicating hexes here would just be a second
source of truth to keep in sync. When tmux comes back into scope, give it
`tmux/themes/<name>.conf` includes rather than adding palette data to these manifests.

## Runtime state lives elsewhere

A manifest is a *definition* and never changes when you switch themes. Which theme is
*active* is runtime state, kept outside this repo at
`~/.local/state/dotfiles-theme/current` (plus the gitignored `ghostty/theme.conf`), so
switching themes leaves `git status` clean.

## The themes that ship today

Thirteen, all using plugins that are already installed — adding any of them required
no `:Lazy` command. Both halves of a theme must exist: a ghostty theme that resolves
and an nvim colorscheme whose plugin is present.

| Theme | ghostty | nvim | bg |
|---|---|---|---|
| `everforest` | `everforest-dark-medium` (local) | everforest-nvim | dark |
| `everforest-light` | `everforest-light-medium` (local) | everforest-nvim | light |
| `tokyonight` | `tokyonight_night` | tokyonight.nvim | dark |
| `tokyonight-storm` | `tokyonight-storm` | tokyonight.nvim | dark |
| `tokyonight-moon` | `tokyonight_moon` | tokyonight.nvim | dark |
| `tokyonight-day` | `tokyonight-day` | tokyonight.nvim | light |
| `nightfox` | `nightfox` | nightfox.nvim | dark |
| `nordfox` | `nordfox` | nightfox.nvim | dark |
| `duskfox` | `duskfox` | nightfox.nvim | dark |
| `terafox` | `terafox` | nightfox.nvim | dark |
| `carbonfox` | `carbonfox` | nightfox.nvim | dark |
| `dawnfox` | `dawnfox` | nightfox.nvim | light |
| `dayfox` | `dayfox` | nightfox.nvim | light |

Ghostty also ships kanagawa, rose-pine, catppuccin, gruvbox and solarized themes.
Each needs its nvim plugin installed first — **your** job in a live `nvim`, then a
manifest here.

## Why this directory is not a submodule

A `theme.env` is a mapping specific to this machine's stack: these ghostty theme
names, these installed nvim plugins, these wallpaper directories. There is no
upstream to consume it from and no second repo to share it with, so a submodule
would add a two-step commit for every theme addition and buy nothing. Wallpapers are
a submodule because they are large binaries with their own lifecycle; ten lines of
text are not.
