#!/usr/bin/env bash
set -euo pipefail

CACHE="${HOME}/.cache/bemenu-notes"
WIDTH_FACTOR="1"

tmp="$(mktemp)"; trap 'rm -f "$tmp" "$tmp.idx"' EXIT

{
  [ -f "$CACHE" ] && cat "$CACHE"
  zk list --format '{{path}}\t{{title}}'
} | awk 'NF' | awk '!seen[$0]++' > "$tmp"


nl -w1 -s $'\t' -ba "$tmp" > "$tmp.idx"

selection="$(
  awk -F'\t' '{print $3 " [#" $1 "]"}' "$tmp.idx" \
  | bemenu -z -l 10 --width-factor "$WIDTH_FACTOR"
)" || exit 0  


if [[ "$selection" =~ \ \[#([0-9]+)\]$ ]]; then
  idx="${BASH_REMATCH[1]}"
  path="$(awk -F'\t' -v i="$idx" '$1==i {print $2; exit}' "$tmp.idx")"
  label="$(awk -F'\t' -v i="$idx" '$1==i {print $3; exit}' "$tmp.idx")"
else
  
  title="$selection"
  
  title="${title#"${title%%[![:space:]]*}"}"
  title="${title%"${title##*[![:space:]]}"}"
  title="${title//$'\t'/ }"
  [ -z "$title" ] && exit 0
  
  path="$(zk new --group inbox --title "$title" --print-path "Inbox")"  
  label="$title"
fi

if [ -n "${path:-}" ]; then
  printf '%s\t%s\n' "$path" "$label" >> "$CACHE"
fi

exec ghostty -e zk edit "$path"
