#!/usr/bin/env bash
set -Eeuo pipefail

export ZK_NOTEBOOK_DIR="$HOME/Documents/Notes/Contents"
journal_dir="${ZK_JOURNAL_DIR:-"$ZK_NOTEBOOK_DIR/Journal"}"
ghostty_class="${GHOSTTY_JOURNAL_CLASS:-ghostty.journal}"

CAPTURE_FILE="$(mktemp)"
mv -f "$CAPTURE_FILE" "${CAPTURE_FILE}.md"
CAPTURE_FILE="${CAPTURE_FILE}.md"
SENTINEL_FILE="$(mktemp)"
rm -f "$SENTINEL_FILE"
cleanup() { rm -f "$CAPTURE_FILE" "$SENTINEL_FILE"; }
trap cleanup EXIT

export ZK_CAPTURE_SENTINEL="$SENTINEL_FILE"
nvim_command=(
    "nvim"
    '-c "let g:zk_capture_written = 0"'
    '-c "augroup ZkJournalCapture | autocmd! |'
    "autocmd BufWritePost <buffer> let g:zk_capture_written = 1 | call writefile(['written'], expand('$ZK_CAPTURE_SENTINEL')) |"
    "autocmd VimLeavePre * if !get(g:, 'zk_capture_written', 0) | cquit | endif | augroup END\""
    '-c "setlocal filetype=markdown"'
    "\"$CAPTURE_FILE\""
)

printf -v nvim_invocation '%s ' "${nvim_command[@]}"
nvim_invocation="${nvim_invocation% }"

if ! ghostty --class="$ghostty_class" -e "$nvim_invocation"; then
    exit 0
fi

[[ -f $SENTINEL_FILE ]] || exit 0

[[ -s $CAPTURE_FILE ]] || exit 0

body="$(cat -- "$CAPTURE_FILE")"

matches="$(zk list "$journal_dir" --created today --format '{{abs-path}}' --limit 2)"
count="$(printf '%s\n' "$matches" | awk 'NF{n++} END{print n+0}')"

if [[ $count -gt 1 ]]; then
    printf 'error: multiple journal notes created today:\n%s\n' "$matches" >&2
    exit 2
fi

if [[ $count -eq 1 ]]; then
    note_path="$matches"
else

    note_path="$(zk new --no-input --print-path "$journal_dir")"
fi

{
    printf '\n'
    printf '%s\n' "$body"
} >>"$note_path"

printf '%s\n' "$note_path"
