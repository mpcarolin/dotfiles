# Working in this repo

Cross-machine dotfiles (nvim, tmux, ghostty, zsh, claude config). Shared between the
personal and work machines — **keep everything here machine-agnostic.** Per-machine values
go in gitignored local files (`nvim/env.lua`, `*.local.json`), never in tracked content.

## Never mutate Neovim's plugin state

Do **not** run any command that installs, updates, pins, restores, or removes Neovim
plugins — from this repo or from any other session:

- `:Lazy sync`, `:Lazy update`, `:Lazy restore`, `:Lazy clean`, `:Lazy install`
- `nvim --headless "+Lazy ..."` in any form
- deleting or checking out anything under `~/.local/share/nvim/lazy/`
- editing `nvim/lazy-lock.json` by hand

`:Lazy sync` bumps every floating-branch plugin at once and has broken this config before.
The lock file and the plugin checkouts must only ever move together, under the user's
control.

**What you may do:** edit plugin *spec* files (`nvim/init.lua`, `nvim/lua/custom/plugins/*.lua`),
`env.template.lua`, and other config. Applying a spec change — installing the plugin,
syncing, updating the lock file — is the user's job in a live `nvim`. If a plan or task
says to run a `:Lazy` command, stop and hand that step to the user.

Verifying a config edit without mutating plugins is fine: `luajit -e "assert(loadfile('init.lua'))"`
to parse-check, `stylua --check`, or `nvim --headless "+lua <inspect>" +qa` that only reads
state.

## Commits

Commit only when the user asks. Never `git push` unprompted. `nvim/` is a submodule with
its own remote — a change there is a separate commit in that repo.
