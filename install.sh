#!/usr/bin/env bash
#
# install.sh — symlink this dotfiles repo into ~/.config and ~/.claude.
#
# Idempotent. Safe to re-run. Existing files that are in the way get backed up
# to ~/.dotfiles-backup/<timestamp>/ before a symlink is created.
#
# NEVER run this on the source machine the repo was authored on — it mutates
# ~/.config and ~/.claude wherever it runs.

set -euo pipefail

# Repo root = directory containing this script.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

log()  { printf '  %s\n' "$*"; }
info() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# link <source> <target>
# (1) already correctly linked -> skip
# (2) something else in the way -> back up, then link
# (3) nothing there -> link
link() {
  local src="$1" dst="$2"

  [ -e "$src" ] || die "source missing: $src"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    log "ok    $dst"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local rel="${dst#"$HOME"/}"
    local bak="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$bak")"
    mv "$dst" "$bak"
    log "moved $dst -> $bak"
  fi

  ln -s "$src" "$dst"
  log "link  $dst -> $src"
}

# ---------------------------------------------------------------------------
# Pre-flight: nvim submodule must be initialized.
# ---------------------------------------------------------------------------
info "Pre-flight checks"
if [ ! -f "$DOTFILES/nvim/init.lua" ]; then
  die "nvim submodule not initialized (nvim/init.lua missing).
     Run: git submodule update --init --recursive"
fi
log "ok    nvim submodule initialized"

# ---------------------------------------------------------------------------
# Whole-directory symlinks.
# ---------------------------------------------------------------------------
info "Linking config directories"
link "$DOTFILES/tmux"    "$HOME/.config/tmux"
link "$DOTFILES/ghostty" "$HOME/.config/ghostty"
link "$DOTFILES/nvim"    "$HOME/.config/nvim"
link "$DOTFILES/claude/hooks" "$HOME/.claude/hooks"

# ---------------------------------------------------------------------------
# Individual-file symlinks (targets sit next to runtime state — link the file,
# never the parent directory).
# ---------------------------------------------------------------------------
info "Linking individual files"
link "$DOTFILES/claude/settings.json"  "$HOME/.claude/settings.json"
link "$DOTFILES/claude/statusline.sh"  "$HOME/.config/claude/statusline.sh"

# ---------------------------------------------------------------------------
# Hand-authored skills — per-skill symlinks. The ~/.claude/skills parent also
# holds third-party symlinks, so it must NOT be replaced wholesale.
# ---------------------------------------------------------------------------
info "Linking hand-authored skills"
mkdir -p "$HOME/.claude/skills"
for skill in "$DOTFILES"/claude/skills/*/; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  link "${skill%/}" "$HOME/.claude/skills/$name"
done

# ---------------------------------------------------------------------------
# Third-party skills — reinstall via the skills CLI. The CLI installs into
# ~/.agents/skills/<name> and symlinks ~/.claude/skills/<name> -> there.
# ---------------------------------------------------------------------------
info "Third-party skills"
MANIFEST="$DOTFILES/claude/third-party-skills.txt"

if [ ! -f "$MANIFEST" ]; then
  warn "no manifest at $MANIFEST — skipping third-party skills"
elif ! command -v npx >/dev/null 2>&1; then
  warn "npx not found — skipping third-party skills. Would have installed:"
  grep -vE '^\s*(#|$)' "$MANIFEST" | while read -r id; do warn "  $id"; done
  warn "Install them later with: npx skills add <source-id> -g -y"
else
  mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills"
  while IFS= read -r line; do
    # strip comments / blanks
    id="${line%%#*}"
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    [ -n "$id" ] || continue
    name="${id##*/}"
    if [ -e "$HOME/.claude/skills/$name" ] || [ -e "$HOME/.agents/skills/$name" ]; then
      log "ok    $name already installed"
      continue
    fi
    log "install $id"
    npx -y skills add "$id" -g -y || warn "failed to install $id"
  done < "$MANIFEST"
fi

info "Done."
log "Backups (if any): $BACKUP_DIR"
