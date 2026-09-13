# Wallpaper sources

Researched 2026-09-12. Nothing here is vendored yet — this is a shortlist with
the catches recorded, so the licensing and size questions do not have to be
re-derived later.

Wallpapers live in the `wallpapers/` submodule, so **repo size matters**: a
multi-GB collection is not submoduleable, and cherry-picking a handful of
images out of one is usually the right move.

## The clean pick

| Repo | Serves | Images / size | License | Stars | Last activity |
|---|---|---|---|---|---|
| [Gurjaka/Everforest-Wallpapers](https://github.com/Gurjaka/Everforest-Wallpapers) | `everforest` | 12 / ~98 MB | **MIT-0** (explicit) | 2 | Dec 2025 |

Curated forest/mountain/landscape work that matches the taste of what is
already in `wallpapers/everforest/`. MIT-0 is the most permissive license
available — no attribution required. Low star count, but the images are real
(verified), not an empty placeholder repo.

## Usable, with caveats

| Repo | Serves | Images / size | License | Stars | The catch |
|---|---|---|---|---|---|
| [linuxdotexe/nordic-wallpapers](https://github.com/linuxdotexe/nordic-wallpapers) | cold-blue family — `tokyonight`, `nordfox` | dozens / ~637 MB | **MIT** (explicit) | 1,859 | Too big to submodule; cherry-pick. Sourcing is transparent (unsplash/wallhaven/reddit, recolored with ImageGoNord). Check `wallpaper-preview.md` before pulling anything. |
| [yukazakiri/themed-wallpapers](https://github.com/yukazakiri/themed-wallpapers) | `everforest`, and folders literally named `tokyo-dark` / `tokyo-moon` / `tokyo-storm` | ~56 per theme / ~1 GB total | **none — no LICENSE file** | 7 | Best *name-level* match for the tokyonight variants, but the licensing is a real gap: images are wallhaven-sourced, which is frequently uncredited reposts. Use the per-theme ZIPs on the Releases page rather than cloning 1 GB. |
| [krishna4a6av/Wallpapers](https://github.com/krishna4a6av/Wallpapers) | `everforest` (39 images), plus catppuccin/gruvbox/kanagawa/oxocarbon | 39 in Everforest alone / 2.45 GB total | **none found** | 199 | The everforest folder genuinely fits (fuji, mountains, forest roads). No license anywhere and the repo is far too large to take wholesale. |

## Rejected

| Repo | Stars | Why not |
|---|---|---|
| [dharmx/walls](https://github.com/dharmx/walls) | 8,934 | 3.8 GB, no license, not foldered usefully by palette. |
| [orangci/walls-catppuccin-mocha](https://github.com/orangci/walls-catppuccin-mocha) | 2,746 | 795 MB, no license, heavily anime/gaming (Hollow Knight, Genshin, Touhou). Wrong taste, wrong palette. |
| [D3Ext/aesthetic-wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) | 3,517 | MIT and ~389 images, but mixes Lain / One Piece / Marvel art in with the landscapes. Heavy vetting needed for a thin payoff. |
| [atraxsrc/tokyonight-wallpapers](https://github.com/atraxsrc/tokyonight-wallpapers) | 106 | GPL-2.0, but it is pixel-art/gaming (pacman, tron, joystick) and bloated with redundant AI-upscale duplicates of the same few images, up to 38 MB each. |
| [FrenzyExists/wallpapers](https://github.com/FrenzyExists/wallpapers) | 776 | MIT, but has a dedicated Anime folder and exactly 1 image in "Green". Nord folder has 43 needing manual vetting. |
| [AngelJumbo/gruvbox-wallpapers](https://github.com/AngelJumbo/gruvbox-wallpapers) | 1,224 | Well organized, but gruvbox is not one of our 13 themes. |

## The gap: six themes have no sourceable wallpapers

Confirmed by direct search, not assumed. **Zero** wallpaper collections exist
for any nightfox variant — every GitHub hit for `nordfox`, `duskfox`,
`terafox`, `carbonfox`, `dawnfox`, `dayfox` is an editor/IDE theme port
(VSCode, Zed, JetBrains), never images. `tokyonight-day` is equally empty: no
light-mode tokyonight wallpapers anywhere.

Coverage by theme:

| Status | Themes |
|---|---|
| Well served | `everforest`, `everforest-light` |
| Moderate, needs vetting | `tokyonight`, `tokyonight-storm`, `tokyonight-moon`, `nordfox` (via the generic Nord ecosystem) |
| **Nothing available** | `tokyonight-day`, `duskfox`, `terafox`, `carbonfox`, `dawnfox`, `dayfox` |

## Palette conversion — the answer for those six

Rather than hunting for images that do not exist, recolor images we already
have. This also sidesteps the licensing problem entirely: converting our own
`wanderers/` set is not redistributing someone's unlicensed repost pile.

| Tool | Stars | License | Notes |
|---|---|---|---|
| [Achno/gowall](https://github.com/Achno/gowall) | 2,313 | MIT | **The recommended one.** Converts any image to a target palette; everforest, tokyonight and nord are built in, and custom hex palettes are supported — which is how the nightfox variants get covered. Actively maintained. |
| [ozwaldorf/lutgen-rs](https://github.com/ozwaldorf/lutgen-rs) | 591 | MIT | LUT-based and very fast. Better if the goal is a scripted batch pipeline over a one-off conversion. |
| [Schroedinger-Hat/ImageGoNord](https://github.com/Schroedinger-Hat/ImageGoNord) | 936 | AGPL-3.0 | Nord only, so narrower than gowall. AGPL is more restrictive if converted output is ever redistributed. |

The nightfox hex values needed for a custom palette are already on this
machine, in the installed plugin:
`~/.local/share/nvim/lazy/nightfox.nvim/lua/nightfox/palette/*.lua`.
