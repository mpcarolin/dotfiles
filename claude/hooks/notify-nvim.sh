#!/bin/bash
# Notify Neovim when Claude Code needs attention.
# Called by Claude Code's Stop and Notification hooks. Receives JSON context on stdin.

# Exit silently if not running inside Neovim's terminal
[ -z "$NVIM" ] && exit 0

# Use CLI argument as message, or fall back to default
MSG="${1:-Claude is ready for you}"

# Build notification title, including tmux session name if available
TITLE="Claude Code"
if [ -n "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
  TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
  [ -n "$TMUX_SESSION" ] && TITLE="Claude Code [$TMUX_SESSION]"
fi

# Consume stdin (required by hook protocol)
cat > /dev/null

# Play chime if a sound file is specified as $2
[ -n "$2" ] && afplay "$2" &

# Send notification to Neovim
nvim --server "$NVIM" --remote-expr \
  "luaeval('vim.notify(_A[1], vim.log.levels.INFO, {title=_A[2], timeout=10000})', {'$MSG','$TITLE'})" \
  >/dev/null 2>&1

exit 0
