#!/usr/bin/env bash

CAPTURE_FILE="$(mktemp)"
trap 'rm $TMPFILE' EXIT

printf '%% title:\n\n' >"$CAPTURE_FILE"
ghostty --class=ghostty.capture -e "nvim -c \"call matchadd('Comment', '^%.*$')\" \"$CAPTURE_FILE\""

trim() {
  s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf %s "$s"
}

TITLE="$(head -n1 "$CAPTURE_FILE" | sed "s/% title:\(.*\)/\1/")"
TITLE="$(trim "$TITLE")"

BODY="$(tail -n+2 "$CAPTURE_FILE")"
BODY="$(trim "$BODY")"

printf "%s" "$BODY" | zk new --interactive --title "$TITLE" --group=inbox Inbox
