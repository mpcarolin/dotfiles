#!/usr/bin/env bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
dir=$(echo "$input" | jq -r '.workspace.current_dir')
session_name=$(echo "$input" | jq -r '.session_name // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# Total tokens currently in the context window (input + cache tokens from last API call)
tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage // {}) as $u
  | (($u.input_tokens // 0)
     + ($u.cache_creation_input_tokens // 0)
     + ($u.cache_read_input_tokens // 0))
')

# Shorten home dir to ~
dir="${dir/#$HOME/~}"
# Just the basename for compactness — drop this line if you want the full path
dir=$(basename "$dir")

# Git branch (silent if not in a repo)
branch=$(git -C "$(echo "$input" | jq -r '.workspace.current_dir')" branch --show-current 2>/dev/null)

# Colors (ANSI escape codes)
RESET=$'\033[0m'
DIM=$'\033[2m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BLUE=$'\033[34m'
GREY=$'\033[90m'

# Color the token count based on absolute usage
if [ "$tokens" -ge 250000 ]; then
  ctx_color="$RED"
elif [ "$tokens" -ge 150000 ]; then
  ctx_color="$YELLOW"
else
  ctx_color="$GREEN"
fi

# Format token count as e.g. "10k", "180k", "1.2M"
if [ "$tokens" -ge 1000000 ]; then
  tokens_fmt=$(awk -v t="$tokens" 'BEGIN { printf "%.1fM", t/1000000 }')
elif [ "$tokens" -ge 1000 ]; then
  tokens_fmt=$(awk -v t="$tokens" 'BEGIN { printf "%dk", t/1000 }')
else
  tokens_fmt="$tokens"
fi

# Build a 20-character progress bar scaled to token thresholds
# Full bar at 250k tokens (the red threshold); each segment = 12.5k tokens
BAR_WIDTH=20
BAR_CAP=250000
filled=$(( tokens * BAR_WIDTH / BAR_CAP ))
[ "$filled" -lt 0 ] && filled=0
[ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
# Show at least 1 segment when there's any usage
if [ "$filled" -eq 0 ] && [ "$tokens" -gt 0 ]; then
  filled=1
fi
empty=$((BAR_WIDTH - filled))
printf -v fill_str "%${filled}s"
printf -v empty_str "%${empty}s"
bar="[${fill_str// /=}${empty_str// /-}]"

ctx_str=$(printf "${ctx_color}%s${RESET} ${ctx_color}%s${RESET}" "$tokens_fmt" "$bar")

# Line 1: dir, branch, ctx
if [ -n "$branch" ]; then
  printf "${CYAN}%s${RESET} ${DIM}⎇${RESET} ${BLUE}%s${RESET} ${DIM}|${RESET} ${DIM}ctx:${RESET} %s\n" "$dir" "$branch" "$ctx_str"
else
  printf "${CYAN}%s${RESET} ${DIM}|${RESET} ${DIM}ctx:${RESET} %s\n" "$dir" "$ctx_str"
fi

# Line 2: session name (only if custom) + model
if [ -n "$session_name" ]; then
  printf "${YELLOW}%s${RESET} ${DIM}|${RESET} ${GREY}%s${RESET}" "$session_name" "$model"
else
  printf "${GREY}%s${RESET}" "$model"
fi
