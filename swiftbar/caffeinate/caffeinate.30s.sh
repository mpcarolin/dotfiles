#!/usr/bin/env bash
# <xbar.title>Caffeinate</xbar.title>
# <xbar.desc>Keep the Mac awake with /usr/bin/caffeinate: toggle on/off or run for a fixed time.</xbar.desc>
# <xbar.dependencies>bash,caffeinate</xbar.dependencies>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
#
# Usage (menu actions call these):
#   caffeinate.30s.sh on [seconds]   start; indefinite when no seconds given
#   caffeinate.30s.sh off            stop the caffeinate this plugin started
#
# Only the caffeinate whose PID this plugin recorded is ever stopped.

set -u

CAFFEINATE=/usr/bin/caffeinate
FLAGS=-di # -d: no display sleep, -i: no idle system sleep
STATE_DIR="${HOME}/Library/Caches/swiftbar-caffeinate"
PID_FILE="$STATE_DIR/pid"
END_FILE="$STATE_DIR/end" # epoch seconds when a timed session ends; 0 = indefinite
STARTED_FILE="$STATE_DIR/started" # process start time, guards against PID reuse

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

clear_state() { rm -f "$PID_FILE" "$END_FILE" "$STARTED_FILE"; }

started_at() { ps -p "$1" -o lstart= 2>/dev/null; }

# Prints our PID if the recorded process is still the caffeinate we started
# (same PID, same command, same start time).
running_pid() {
  local pid comm
  [ -f "$PID_FILE" ] || return 1
  pid="$(cat "$PID_FILE")"
  case "$pid" in '' | *[!0-9]*) clear_state; return 1 ;; esac
  comm="$(ps -p "$pid" -o comm= 2>/dev/null)"
  if [ "${comm##*/}" != caffeinate ] ||
    [ "$(started_at "$pid")" != "$(cat "$STARTED_FILE" 2>/dev/null)" ]; then
    clear_state
    return 1
  fi
  printf '%s\n' "$pid"
}

stop() {
  local pid
  pid="$(running_pid)" && kill "$pid" 2>/dev/null
  clear_state
}

start() {
  local secs="${1:-}" pid
  stop
  mkdir -p "$STATE_DIR"
  if [ -n "$secs" ]; then
    nohup "$CAFFEINATE" "$FLAGS" -t "$secs" >/dev/null 2>&1 &
    pid=$!
    echo $(($(date +%s) + secs)) >"$END_FILE"
  else
    nohup "$CAFFEINATE" "$FLAGS" >/dev/null 2>&1 &
    pid=$!
    echo 0 >"$END_FILE"
  fi
  disown "$pid" 2>/dev/null
  started_at "$pid" >"$STARTED_FILE"
  echo "$pid" >"$PID_FILE"
}

# 3720 -> "1h 02m", 540 -> "9m" (minutes rounded up).
fmt_remaining() {
  local mins=$((($1 + 59) / 60))
  if [ "$mins" -ge 60 ]; then
    printf '%dh %02dm' $((mins / 60)) $((mins % 60))
  else
    printf '%dm' "$mins"
  fi
}

render() {
  local action="bash=\"$SELF\" terminal=false refresh=true"
  local end=0 remaining=0

  if running_pid >/dev/null; then
    end="$(cat "$END_FILE" 2>/dev/null || echo 0)"
    case "$end" in '' | *[!0-9]*) end=0 ;; esac
    if [ "$end" -gt 0 ]; then
      remaining=$((end - $(date +%s)))
      [ "$remaining" -lt 0 ] && remaining=0
      echo "$(fmt_remaining "$remaining") | sfimage=cup.and.saucer.fill"
    else
      echo " | sfimage=cup.and.saucer.fill"
    fi
    echo "---"
    if [ "$end" -gt 0 ]; then
      echo "Awake until $(date -r "$end" '+%-I:%M %p') ($(fmt_remaining "$remaining") left)"
    else
      echo "Awake indefinitely"
    fi
    echo "Turn Off | $action param1=off sfimage=moon.zzz"
  else
    echo " | sfimage=cup.and.saucer"
    echo "---"
    echo "Caffeinate is off"
    echo "Turn On | $action param1=on sfimage=sun.max"
  fi

  echo "Keep Awake For | sfimage=timer"
  local entry label secs
  for entry in 15m:900 30m:1800 45m:2700 1h:3600 2h:7200 4h:14400 6h:21600 8h:28800; do
    label="${entry%%:*}"
    secs="${entry##*:}"
    echo "--$label | $action param1=on param2=$secs"
  done
}

case "${1:-}" in
  on) start "${2:-}" ;;
  off) stop ;;
  *) render ;;
esac
