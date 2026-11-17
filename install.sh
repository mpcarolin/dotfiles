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
# Homebrew packages the linked configs depend on.
# ---------------------------------------------------------------------------
info "Homebrew packages"
if ! command -v brew >/dev/null 2>&1; then
  warn "brew not found — skipping. Install Rift later with: brew install acsandmann/tap/rift"
elif brew list --formula acsandmann/tap/rift >/dev/null 2>&1; then
  log "ok    rift already installed"
else
  log "install rift"
  brew install acsandmann/tap/rift
  log "      to start it: \`rift service install && rift service start\`, allow Rift in"
  log "      System Settings → Privacy & Security → Accessibility, then \`rift service restart\`"
fi
# Rift requires "Displays have separate Spaces" (on by default; spans-displays=1 means off).
if [ "$(defaults read com.apple.spaces spans-displays 2>/dev/null)" = "1" ]; then
  warn "Rift needs System Settings → Desktop & Dock → Mission Control → \"Displays have separate Spaces\" turned on (takes effect after logging out)"
fi

# ---------------------------------------------------------------------------
# Whole-directory symlinks.
# ---------------------------------------------------------------------------
info "Linking config directories"
link "$DOTFILES/tmux"    "$HOME/.config/tmux"
link "$DOTFILES/ghostty" "$HOME/.config/ghostty"
link "$DOTFILES/rift"    "$HOME/.config/rift"
link "$DOTFILES/nvim"    "$HOME/.config/nvim"
link "$DOTFILES/hammerspoon" "$HOME/.hammerspoon"
link "$DOTFILES/claude/hooks" "$HOME/.claude/hooks"

# ---------------------------------------------------------------------------
# Individual-file symlinks (targets sit next to runtime state — link the file,
# never the parent directory).
# ---------------------------------------------------------------------------
info "Linking individual files"
link "$DOTFILES/claude/settings.json"  "$HOME/.claude/settings.json"
link "$DOTFILES/claude/statusline.sh"  "$HOME/.config/claude/statusline.sh"
link "$DOTFILES/herdr/config.toml"     "$HOME/.config/herdr/config.toml"

# ---------------------------------------------------------------------------
# Executables. ~/.local/bin is expected to be on PATH.
# ---------------------------------------------------------------------------
info "Linking executables"
mkdir -p "$HOME/.local/bin"
link "$DOTFILES/bin/theme" "$HOME/.local/bin/theme"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) warn "$HOME/.local/bin is not on PATH — add it to use \`theme\`" ;;
esac

# ---------------------------------------------------------------------------
# SwiftBar plugins — per-plugin symlinks into whatever folder SwiftBar was
# pointed at on this machine. Skipped when SwiftBar isn't configured.
# ---------------------------------------------------------------------------
info "Linking SwiftBar plugins"
SWIFTBAR_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
if [ -z "$SWIFTBAR_DIR" ]; then
  log "skip  SwiftBar plugin folder not configured"
else
  # Each plugin lives in swiftbar/<name>/; only its executables get linked.
  for plugin in "$DOTFILES"/swiftbar/*/*; do
    [ -f "$plugin" ] && [ -x "$plugin" ] || continue
    link "$plugin" "$SWIFTBAR_DIR/$(basename "$plugin")"
  done
fi

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
    # "<source-id> [skill-name]"; skill-name defaults to the repo name.
    read -r id skill _ <<<"${line%%#*}"
    [ -n "${id:-}" ] || continue
    name="${skill:-${id##*/}}"
    if [ -e "$HOME/.claude/skills/$name" ] || [ -e "$HOME/.agents/skills/$name" ]; then
      log "ok    $name already installed"
      continue
    fi
    log "install $id ${skill:-}"
    npx -y skills add "$id" -g -y ${skill:+--skill "$skill"} || warn "failed to install $id"
  done < "$MANIFEST"
fi

info "Done."
log "Backups (if any): $BACKUP_DIR"
