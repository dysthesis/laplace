#!/usr/bin/env bash

CAPTURE_FILE="$(mktemp)"
SENTINEL_FILE="$(mktemp)"
NOTES_PATH="$HOME/Documents/Notes"
rm -f "$SENTINEL_FILE"
trap 'rm -f "$CAPTURE_FILE" "$SENTINEL_FILE"' EXIT

export ZK_CAPTURE_SENTINEL="$SENTINEL_FILE"

printf '%% title:\n\n' >"$CAPTURE_FILE"

nvim_command=(
    "nvim"
    '-c "let g:zk_capture_written = 0"'
    "-c \"augroup ZkCaptureGuard | autocmd! | autocmd BufWritePost <buffer> let g:zk_capture_written = 1 | call writefile(['written'], expand('$ZK_CAPTURE_SENTINEL')) | autocmd VimLeavePre * if !get(g:, 'zk_capture_written', 0) | cquit | endif | augroup END\""
    "-c \"call matchadd('Comment', '^%.*$')\""
    "\"$CAPTURE_FILE\""
)

printf -v nvim_invocation '%s ' "${nvim_command[@]}"
nvim_invocation="${nvim_invocation% }"

if ! ghostty --class=ghostty.capture -e "$nvim_invocation"; then
    exit 0
fi

if [[ ! -f $SENTINEL_FILE ]]; then
    exit 0
fi

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

COMMIT_MESSAGE="Inbox capture at $(date +"%Y-%m-%d %H:%M:%S"): $TITLE"
git -C "$NOTES_PATH" pull
git -C "$NOTES_PATH" add "$NOTES_PATH/Contents/Inbox"
git -C "$NOTES_PATH" commit -am "$COMMIT_MESSAGE"
git -C "$NOTES_PATH" push -u
