# dotfiles

Personal config for tmux, Ghostty, Claude Code, and Neovim (a
[kickstart.nvim](https://github.com/mpcarolin/kickstart.nvim) fork, vendored as a submodule).

`install.sh` symlinks everything into place. It never copies: the repo is the
source of truth, and edits flow straight back through the links.

## Quick Start

```sh
git clone --recurse-submodules git@github.com:mpcarolin/dotfiles.git ~/Development/dotfiles
cd ~/Development/dotfiles
./install.sh
```

`install.sh` is idempotent. Anything already in the way is backed up to
`~/.dotfiles-backup/<timestamp>/` before the symlink is created.

## Forgot `--recurse-submodules`?

```sh
git submodule update --init --recursive
```

`install.sh` will refuse to run until `nvim/init.lua` exists.

## What gets linked

| Repo path                   | Linked to                               |
|-----------------------------|-----------------------------------------|
| `tmux/`                     | `~/.config/tmux`                        |
| `ghostty/`                  | `~/.config/ghostty`                     |
| `nvim/`                     | `~/.config/nvim`                        |
| `claude/settings.json`      | `~/.claude/settings.json`               |
| `claude/hooks/`             | `~/.claude/hooks`                       |
| `claude/statusline.sh`      | `~/.config/claude/statusline.sh`        |
| `claude/skills/<name>`      | `~/.claude/skills/<name>` (per-skill)   |

`~/.claude/skills/` is shared with third-party skills, so skills are linked one
at a time — the parent directory is never replaced.

## Updating dotfiles

Edit any file in the repo (or, since targets are symlinks, edit through
`~/.config/...`), then commit and push from the repo root:

```sh
cd ~/Development/dotfiles
git add -A && git commit -m "..." && git push
```

## Updating the nvim config

The nvim config is a submodule pointing at the `mpcarolin/kickstart.nvim` fork.
Edit and commit inside it, then record the new pointer in this repo:

```sh
cd ~/Development/dotfiles/nvim
# edit, then:
git add -A && git commit -m "..." && git push
cd ..
git add nvim && git commit -m "bump nvim" && git push
```

## Pulling upstream kickstart.nvim

One-time, add the upstream remote inside the submodule:

```sh
cd ~/Development/dotfiles/nvim
git remote add upstream https://github.com/nvim-lua/kickstart.nvim.git
```

Then to pull upstream changes into the fork:

```sh
cd ~/Development/dotfiles/nvim
git fetch upstream
git merge upstream/master      # resolve conflicts
git push origin master         # push to the fork
cd ..
git add nvim && git commit -m "merge upstream kickstart.nvim" && git push
```

## Pulling latest everything

```sh
git pull --recurse-submodules
```

## Adding a third-party skill

```sh
npx skills add <owner>/<repo> -g -y
```

Then record it so a fresh machine reinstalls it:

```sh
echo '<owner>/<repo>' >> claude/third-party-skills.txt
git add claude/third-party-skills.txt && git commit -m "add skill <name>"
```

## Adding a hand-authored skill

Drop the skill directory under `claude/skills/<name>/`, commit it, and re-run
`install.sh` to link it (the skills parent is not symlinked, so each new skill
needs its own link):

```sh
git add claude/skills/<name> && git commit -m "add skill <name>"
./install.sh
```

## Machine-local overrides

`settings.local.json` is gitignored. Put per-machine Claude Code tweaks there —
they layer over `settings.json` without touching the tracked file.
