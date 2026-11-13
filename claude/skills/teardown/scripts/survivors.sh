#!/usr/bin/env bash
# Lists processes running inside a worktree that are detached from any terminal, so closing
# Herdr's panes does not signal them. Each line is the root of one detached subtree.
# Kind is `detached` when nothing above the root holds a terminal (it already outlives its
# launcher), or `background:<comm>` when it hangs under a terminal process such as `claude`
# (Claude background tasks run in their own session and survive the pane closing).
# `chrome-helper` marks Chrome crash handlers that headless-browser daemons leave behind under launchd.
# Left out: the shell running this script and its ancestors (the teardown session itself).
# Usage: bash survivors.sh <worktree-path>
# Output: pid<TAB>descendants<TAB>kind<TAB>command
set -euo pipefail
wt="${1:?worktree path required}"

table=$(ps -axo pid=,ppid=,tty=)
field() { awk -v p="$1" -v f="$2" '$1==p {print $f}' <<<"$table"; }

# The shell running this script and everything above it is the teardown session itself
self=""
cur=$$
while [ -n "$cur" ] && [ "$cur" -gt 1 ]; do
  self="$self $cur "
  cur=$(field "$cur" 2)
done

inside=$(
  lsof -nP -d cwd -Fpn 2>/dev/null \
    | awk '/^p/{p=substr($0,2)} /^n/{print p"\t"substr($0,2)}' \
    | awk -F'\t' -v wt="$wt" '$2==wt || index($2, wt"/")==1 {print $1}' \
    | sort -un
)

# A detached process's subtree root: walk up while the parent is also detached
for pid in $inside; do
  [ "$(field "$pid" 3)" = "??" ] || continue
  case "$self" in *" $pid "*) continue ;; esac
  cur=$pid
  while :; do
    parent=$(field "$cur" 2)
    { [ -z "$parent" ] || [ "$parent" -le 1 ] || [ "$(field "$parent" 3)" != "??" ]; } && break
    cur=$parent
  done
  echo "$cur"
done | sort -n | uniq -c | while read -r count root; do
  args=$(ps -o command= -p "$root" 2>/dev/null) || continue
  parent=$(field "$root" 2)
  kind=detached
  case "$args" in *chrome_crashpad_handler*) kind=chrome-helper ;; esac
  if [ -n "$parent" ] && [ "$parent" -gt 1 ]; then
    kind="background:$(basename "$(ps -o comm= -p "$parent")")"
  fi
  exe=$(awk '{print $1}' <<<"$args")
  printf '%s\t%s\t%s\t%s\n' "$root" "$((count - 1))" "$kind" "$(basename "$exe")${args#"$exe"}" | cut -c1-220
done
