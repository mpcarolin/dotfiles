#!/bin/bash
# notify-macos.sh — Claude Code notifier hook

MSG="${1:-Done}"
SOUND="${2:-Glass}"

TMUX_SOCKET=$(echo "$TMUX" | cut -d, -f1)
TMUX_BIN="/opt/homebrew/bin/tmux"

tmux_cmd() { "$TMUX_BIN" -S "$TMUX_SOCKET" "$@"; }

# Skip if the user is looking at this exact pane AND the nvim terminal buffer is visible.
# Both conditions must be true — the tmux pane could be active but the terminal toggled closed,
# or the terminal could be open but in a different tmux window the user isn't viewing.
PANE_FOCUSED=$(tmux_cmd display-message -t "$TMUX_PANE" -p '#{pane_active}#{window_active}')
# if [ "$PANE_FOCUSED" = "11" ] && [ -n "$NVIM" ]; then
#   ANCESTOR=$$
#   while [ "$ANCESTOR" -gt 1 ]; do
#     VISIBLE=$(nvim --server "$NVIM" --remote-expr \
#       "luaeval('(function() for _, buf in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[buf].buftype == \"terminal\" then local chan = vim.b[buf].terminal_job_id if chan and vim.fn.jobpid(chan) == _A then return #vim.fn.win_findbuf(buf) > 0 and 1 or 0 end end end return -1 end)()', $ANCESTOR)" 2>/dev/null)
#     [ "$VISIBLE" = "1" ] && exit 0
#     [ "$VISIBLE" = "0" ] && break
#     ANCESTOR=$(ps -o ppid= -p "$ANCESTOR" 2>/dev/null | tr -d " ")
#     [ -z "$ANCESTOR" ] && break
#   done
# fi

SESSION=$(tmux_cmd display-message -t "$TMUX_PANE" -p '#{session_name}')
WINDOW=$(tmux_cmd display-message -t "$TMUX_PANE" -p '#{window_index}')

T="$TMUX_BIN -S '$TMUX_SOCKET'"
ON_CLICK="osascript -e 'tell application \"Ghostty\" to activate'"
ON_CLICK+=" && $T switch-client -t '${SESSION}' 2>/dev/null"
ON_CLICK+="; $T select-window -t '${SESSION}:${WINDOW}'"
ON_CLICK+="; $T select-pane -t '${TMUX_PANE}'"

ID="${SESSION}:${WINDOW}"

terminal-notifier \
  -group "${ID}" \
  -sound "$SOUND" \
  -execute "$ON_CLICK" \
  -title "Claude (${SESSION})" \
  -message "$MSG (${ID} ${TMUX_PANE})"
