#!/usr/bin/env bash
set -euo pipefail

BIB="${1:-$HOME/Library/Library.bib}"
FILES="${2:-$HOME/Library/Files}"

need() { command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing dependency: %s\n' "$1" >&2
    exit 127
}; }
need pandoc
need jq
need bemenu
need fd

regex_escape() {
    sed -e 's/[.[\*^$+?(){|\\]/\\&/g'
}

title_to_relaxed_regex() {
    tr '[:upper:]' '[:lower:]' |
        tr -s '[:space:]' ' ' |
        sed -E 's/[^[:alnum:]]+/.*/g' |
        sed -E 's/(\.\*)+/.*/g' |
        sed -E 's/^\.\*//; s/\.\*$//'
}

open_file() {
    local f=$1
    if command -v xdg-open >/dev/null 2>&1; then
        nohup xdg-open "$f" >/dev/null 2>&1 &
    elif command -v gio >/dev/null 2>&1; then
        nohup gio open "$f" >/dev/null 2>&1 &
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        nohup open "$f" >/dev/null 2>&1 &
    else
        printf 'No known opener found for: %s\n' "$f" >&2
        return 1
    fi
}

find_pdf_for_item() {
    local dir="$1" first_family="$2" year="$3" title="$4"
    local -a hits=()

    local title_relaxed author_relaxed pattern
    title_relaxed=$(printf '%s' "$title" | title_to_relaxed_regex)
    author_relaxed=$(printf '%s' "$first_family" | tr '[:upper:]' '[:lower:]' | regex_escape)

    if [[ -n $author_relaxed && -n $year && -n $title_relaxed ]]; then
        pattern="^${author_relaxed}.* - ${year} - ${title_relaxed}.*\\.pdf$"

        mapfile -d '' -t hits < <(fd -uu -i -t f -e pdf --hidden --regex "$pattern" "$dir" -0 || true)
    fi

    if [[ ${#hits[@]} -eq 0 ]]; then
        local literal
        literal=$(printf '%s' "$title" | regex_escape)
        mapfile -d '' -t hits < <(fd -uu -i -t f -e pdf --hidden --regex "$literal" "$dir" -0 || true)
    fi

    if [[ ${#hits[@]} -eq 1 ]]; then
        printf '%s\n' "${hits[0]}"
        return 0
    elif [[ ${#hits[@]} -gt 1 ]]; then

        local preview='echo {}'
        if command -v pdftotext >/dev/null 2>&1; then
            preview='pdftotext -l 1 -layout {} - | sed -n "1,80p"'
        fi
        local choice
        if choice=$(
            printf '%s\n' "${hits[@]}" |
                bemenu --prompt 'Pick PDF:' --fuzzy --ifne
        ); then
            if [[ -n $choice ]]; then
                printf '%s\n' "$choice"
                return 0
            fi
        fi
    fi

    local choice
    if choice=$(
        fd -uu -i -t f -e pdf --hidden . "$dir" |
            bemenu --prompt 'Search PDFs:' --fuzzy --ifne
    ); then
        if [[ -n $choice ]]; then
            printf '%s\n' "$choice"
            return 0
        fi
    fi

    return 1
}

JSON_FILE=$(mktemp)
trap 'rm -f "$JSON_FILE"' EXIT
pandoc -f biblatex -t csljson "$BIB" >"$JSON_FILE"

mapfile -t MENU_ENTRIES < <(
    jq -r '
    .[] |
    select((.id // "") != "") |
    [
      ((.title // "")
        | gsub("^\\s*\"+|\"+\\s*$"; "")
        | gsub("[\\t\\n\\r]+"; " ")
      ),
      ((.author // [])
        | map([.given, .family] | map(select(. != null)) | join(" "))
        | join(", ")
        | gsub("[\\t\\n\\r]+"; " ")
      ),
      (.id // "")
    ] | @tsv
  ' <"$JSON_FILE" |
        sort -u
)

declare -a MENU_LABELS=()
declare -a MENU_IDS=()
declare -a SELECTED_IDS=()

for entry in "${MENU_ENTRIES[@]}"; do
    title=${entry%%$'\t'*}
    rest=${entry#*$'\t'}
    authors=${rest%%$'\t'*}
    id=${entry##*$'\t'}

    # bemenu collapses tabs, so keep a printable label separate from the citekey
    if [[ -n $authors ]]; then
        MENU_LABELS+=("$title - $authors [$id]")
    else
        MENU_LABELS+=("$title [$id]")
    fi
    MENU_IDS+=("$id")
done

local_selection=$(
    printf '%s\n' "${MENU_LABELS[@]}" |
        bemenu --prompt 'Search:' -l 10 --fuzzy --ifne --counter always
) || exit 0

[[ -n $local_selection ]] || exit 0

selection_index=-1
for i in "${!MENU_LABELS[@]}"; do
    if [[ ${MENU_LABELS[$i]} == "$local_selection" ]]; then
        selection_index=$i
        break
    fi
done

((selection_index >= 0)) || exit 0

SELECTED_IDS=("${MENU_IDS[$selection_index]}")

if ((${#SELECTED_IDS[@]} == 0)); then
    exit 0
fi

SELECTION_IDS=$(printf '%s\n' "${SELECTED_IDS[@]}")

while IFS= read -r id; do

    mapfile -d $'\0' -t F < <(
        jq -r --arg id "$id" '
      .[] | select(.id == $id) |
      
      ((.author // []) | first | .family // "") as $first_family |
      ((.issued["date-parts"][0][0]) // "") as $year |
      ((.author // [])
        | map([.given, .family] | map(select(. != null)) | join(" "))
      ) as $authors |
      [
        (.id // ""),
        (if .URL then .URL elif .DOI then "https://doi.org/" + .DOI else "" end),
        ((.title // "") | gsub("^\\s*\"+|\"+\\s*$"; "")),
        (.abstract // ""),
        ($authors | map("  - " + tojson) | join("\n")),
        ($year | tostring),
        ($first_family)
      ] | join("\u0000") + "\u0000"
    ' <"$JSON_FILE"
    )

    id=${F[0]}
    ref=${F[1]}
    title=${F[2]}
    abstract=${F[3]//$'\r'/}
    authors_yaml=${F[4]}
    year=${F[5]}
    first_family=${F[6]}

    [[ -n $authors_yaml ]] || authors_yaml='  - ""'

    if pdf_path=$(find_pdf_for_item "$FILES" "$first_family" "$year" "$title"); then
        open_file "$pdf_path" || printf 'Failed to open: %s\n' "$pdf_path" >&2
    else
        printf 'No PDF matched for: %s (%s, %s)\n' "$title" "$first_family" "$year" >&2
    fi

    note_path=""
    if note_info=$(
        ZK_AUTHORS_YAML="$authors_yaml" \
            ZK_DESC="$abstract" \
            ZK_REF="$ref" \
            zk new Literature --title "$title" --id "$id" --print-path --no-input
    ); then
        note_path=$(printf '%s\n' "$note_info" | sed -n '1p')
        note_path=${note_path//$'\r'/}
    else
        printf 'Failed to create literature note for: %s\n' "$id" >&2
    fi

    if [[ -z $note_path || $note_path == '---' ]]; then
        note_path=$(zk list Literature --format '{{path}}' --match "$id" --match-strategy exact --limit 1 --quiet | head -n 1)
        note_path=${note_path//$'\r'/}
    fi

    if [[ -n $note_path ]]; then
        if command -v ghostty >/dev/null 2>&1; then
            nohup ghostty -e zk edit "$note_path" >/dev/null 2>&1 &
        else
            zk edit "$note_path"
        fi
    else
        printf 'Unable to locate literature note for: %s\n' "$id" >&2
    fi

done <<<"$SELECTION_IDS"
