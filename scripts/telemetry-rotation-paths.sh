# shellcheck shell=bash
# This shared helper checks paths without reading or decrypting secrets.
telemetry_rotation_source() {
    local root=$1 relative=$2 destination resolved
    if [[ $root != /* || $root == /nix/store || $root == /nix/store/* ||
        ! $relative =~ ^system/secrets/[A-Za-z0-9][A-Za-z0-9._-]*\.(yaml|json)$ ]]; then
        printf 'unsupported telemetry source: %s/%s\n' "$root" "$relative" >&2
        return 1
    fi
    destination="$root/$relative"
    resolved=$(realpath --canonicalize-existing -- "$destination") || return 1
    if [[ $resolved != "$destination" || ! -f $destination || ! -r $destination ||
        ! -w $destination || ! -w ${destination%/*} ]]; then
        printf 'telemetry source must be a writable regular repository file without symlinks: %s\n' "$destination" >&2
        return 1
    fi
    printf '%s\n' "$destination"
}
