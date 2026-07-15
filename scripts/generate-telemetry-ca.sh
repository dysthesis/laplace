#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

for command in cmp mktemp openssl; do
    command -v "$command" >/dev/null ||
        die "missing $command; run with: nix shell nixpkgs#openssl -c $0"
done

[[ $# -eq 0 ]] || die "usage: $0"
[[ -w /dev/shm ]] || die '/dev/shm must be writable; plaintext keys must stay on tmpfs'

umask 077
output_dir=$(mktemp -d /dev/shm/laplace-new-ca.XXXXXX)
complete=false
cleanup() {
    if [[ $complete != true ]]; then
        rm -rf -- "$output_dir"
    fi
}
trap cleanup EXIT HUP INT TERM

key="$output_dir/new-ca.key"
certificate="$output_dir/new-ca.crt"

openssl genpkey -algorithm ED25519 -out "$key"
openssl req \
    -x509 \
    -new \
    -key "$key" \
    -set_serial "0x$(openssl rand -hex 16)" \
    -days 3650 \
    -subj '/CN=Laplace Telemetry Client CA 2026-07' \
    -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
    -addext 'keyUsage=critical,keyCertSign,cRLSign' \
    -addext 'subjectKeyIdentifier=hash' \
    -out "$certificate"

openssl pkey -in "$key" -check -noout >/dev/null
openssl verify -CAfile "$certificate" "$certificate" >/dev/null
openssl x509 -in "$certificate" -checkend $((9 * 365 * 24 * 60 * 60)) -noout >/dev/null ||
    die 'generated CA has an unexpectedly short lifetime'
cmp -s \
    <(openssl x509 -in "$certificate" -pubkey -noout) \
    <(openssl pkey -in "$key" -pubout) ||
    die 'generated CA certificate and private key do not match'

complete=true
printf 'Generated and validated CA in tmpfs:\n'
printf '  certificate: %s\n' "$certificate"
printf '  private key: %s\n\n' "$key"
openssl x509 \
    -in "$certificate" \
    -noout \
    -subject \
    -issuer \
    -serial \
    -dates \
    -fingerprint \
    -sha256
printf '\nNext:\n'
printf '  ./scripts/rotate-telemetry-ca.sh %q %q\n' "$certificate" "$key"
printf '\nAfter successful rotation, remove plaintext material:\n'
printf '  rm -rf -- %q\n' "$output_dir"
