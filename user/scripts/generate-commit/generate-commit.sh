#!/usr/bin/env sh

set -eu
MODEL="${OLLAMA_MODEL:-qwen2.5-coder:3b}"
N="${N_SUGGESTIONS:-8}"

if git rev-parse --git-dir >/dev/null 2>&1; then
    git diff --cached --quiet && {
        printf >&2 "Nothing staged.\n"
        exit 1
    }
    DIFF="$(git diff --cached --no-color -U0)"
else
    DIFF="$(
        jj diff --ignore-working-copy >/dev/null 2>&1 || true
        jj diff -s || true
    )"
fi

JSON="$(
    curl -sS http://localhost:11434/api/chat \
        -H 'Content-Type: application/json' \
        -d @- <<JSON
{
  "model": "$MODEL",
  "stream": false,
  "format": {
    "type": "object",
    "properties": { "suggestions": { "type": "array", "items": { "type": "string" } } },
    "required": ["suggestions"]
  },
  "messages": [
    { "role": "system", "content": "You write succinct Conventional Commit messages." },
    { "role": "user", "content": "Generate $N one-line commit subjects (<= 72 chars) for this diff:\\n\\n$DIFF" }
  ]
}
JSON
)"

list() {
    printf '%s\n' "$JSON" | jq -r '.message.content | fromjson | .suggestions[]'
}

case "${1-}" in
--list) list ;;
*)
    list |
        fzf --prompt='commit> ' --height=40% --reverse \
            --preview 'git diff --cached --color=always | sed -n "1,200p"' |
        sed 's/[[:space:]]\+$//'
    ;;
esac
