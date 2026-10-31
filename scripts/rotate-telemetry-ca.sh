#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly repo_dir
source "$repo_dir/scripts/telemetry-rotation-paths.sh"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

for command in cmp jq mktemp nix openssl realpath sops; do
    command -v "$command" >/dev/null ||
        die "missing $command; run with: nix shell nixpkgs#coreutils nixpkgs#jq nixpkgs#openssl nixpkgs#sops -c $0"
done

[[ $# -eq 2 ]] || die "usage: $0 <new-ca-certificate.pem> <new-ca-private-key.pem>"
readonly ca_certificate_input=$1
readonly ca_key_input=$2
[[ -r $ca_certificate_input ]] || die "cannot read CA certificate: $ca_certificate_input"
[[ -r $ca_key_input ]] || die "cannot read CA private key: $ca_key_input"

[[ -w /dev/shm ]] || die '/dev/shm must be writable; plaintext keys must stay on tmpfs'
plan=$(nix eval --extra-experimental-features 'nix-command flakes pipe-operators' --no-write-lock-file --json "$repo_dir#telemetryRotationPlan")
readonly plan
mapfile -t hosts < <(jq -r '.writers | keys[]' <<< "$plan")
mapfile -t secret_files < <(jq -r '.files[]' <<< "$plan")
readonly -a hosts secret_files
declare -A source_files=()
for file in "${secret_files[@]}"; do
    source_files[$file]=$(telemetry_rotation_source "$repo_dir" "$file") ||
        die "unsupported source mapping; no files staged"
done

umask 077
work_dir=$(mktemp -d /dev/shm/laplace-telemetry-ca.XXXXXX)
trap 'rm -rf -- "$work_dir"' EXIT HUP INT TERM
mkdir -p "$work_dir/original/system/secrets" "$work_dir/staged/system/secrets"

for file in "${secret_files[@]}"; do
    cp -- "${source_files[$file]}" "$work_dir/original/$file"
    cp -- "${source_files[$file]}" "$work_dir/staged/$file"
done

openssl x509 -in "$ca_certificate_input" -out "$work_dir/ca.crt" 2>/dev/null ||
    die 'supplied CA certificate is not PEM X.509'
openssl pkey -in "$ca_key_input" -out "$work_dir/ca.key" 2>/dev/null ||
    die 'supplied CA private key is not PEM'
openssl pkey -in "$work_dir/ca.key" -check -noout >/dev/null
openssl verify -CAfile "$work_dir/ca.crt" "$work_dir/ca.crt" >/dev/null
openssl x509 -in "$work_dir/ca.crt" -checkend $((826 * 24 * 60 * 60)) -noout >/dev/null ||
    die 'supplied CA expires before the new 825-day leaves'
cmp -s \
    <(openssl x509 -in "$work_dir/ca.crt" -pubkey -noout) \
    <(openssl pkey -in "$work_dir/ca.key" -pubout) ||
    die 'new CA certificate and private key do not match'

# Keep private key first so future `openssl pkey` extraction fails closed early.
cat "$work_dir/ca.key" "$work_dir/ca.crt" >"$work_dir/ca.pem"

set_secret() {
    local target=$1 value=$2 file key_path
    file=$(jq -r '.file' <<< "$target")
    key_path=$(jq -r '.keyPath' <<< "$target")
    sops set --value-file "$work_dir/staged/$file" "$key_path" "$value"
}

check_secret() {
    local target=$1 expected=$2 file key_path
    file=$(jq -r '.file' <<< "$target")
    key_path=$(jq -r '.keyPath' <<< "$target")
    cmp -s \
        <(sops --decrypt --extract "$key_path" "$work_dir/staged/$file") \
        "$expected" ||
        die "$file $key_path failed staged SOPS validation"
}

declare -A fingerprints=()
declare -A seen_fingerprints=()

for host in "${hosts[@]}"; do
    key="$work_dir/$host.key"
    csr="$work_dir/$host.csr"
    certificate="$work_dir/$host.crt"

    openssl genpkey -algorithm ED25519 -out "$key"
    openssl req -new -key "$key" -subj "/CN=$host" -out "$csr"
    openssl x509 \
        -req \
        -in "$csr" \
        -CA "$work_dir/ca.crt" \
        -CAkey "$work_dir/ca.key" \
        -set_serial "0x$(openssl rand -hex 16)" \
        -days 825 \
        -extfile <(printf '%s\n' \
            'basicConstraints=critical,CA:FALSE' \
            'keyUsage=critical,digitalSignature' \
            'extendedKeyUsage=critical,clientAuth' \
            "subjectAltName=DNS:$host" \
            'subjectKeyIdentifier=hash' \
            'authorityKeyIdentifier=keyid,issuer') \
        -out "$certificate"

    openssl verify -CAfile "$work_dir/ca.crt" -purpose sslclient "$certificate" >/dev/null
    openssl x509 -in "$certificate" -checkhost "$host" -noout >/dev/null
    cmp -s \
        <(openssl x509 -in "$certificate" -pubkey -noout) \
        <(openssl pkey -in "$key" -pubout) ||
        die "$host certificate and private key do not match"
    if openssl verify -CAfile "$work_dir/ca.crt" -purpose sslserver "$certificate" >/dev/null 2>&1; then
        die "$host certificate is unexpectedly valid for TLS server use"
    fi

    read -r fingerprint _ < <(
        openssl x509 -in "$certificate" -outform DER | openssl dgst -sha256 -r
    )
    [[ $fingerprint =~ ^[0-9a-f]{64}$ ]] || die "invalid $host SHA-256 fingerprint"
    [[ -z ${seen_fingerprints[$fingerprint]:-} ]] || die "duplicate fingerprint for $host"
    fingerprints[$host]=$fingerprint
    seen_fingerprints[$fingerprint]=$host

    jq -Rs . <"$certificate" >"$certificate.json"
    jq -Rs . <"$key" >"$key.json"

    writer=$(jq -c --arg host "$host" '.writers[$host]' <<< "$plan")
    set_secret "$(jq -c '.clientCertificate' <<< "$writer")" "$certificate.json"
    set_secret "$(jq -c '.clientKey' <<< "$writer")" "$key.json"
    set_secret "$(jq -c '.receiverCertificate' <<< "$writer")" "$certificate.json"
done

jq -Rs . <"$work_dir/ca.crt" >"$work_dir/ca.crt.json"
jq -Rs . <"$work_dir/ca.pem" >"$work_dir/ca.pem.json"
receiver_ca=$(jq -c '.receiver.ca' <<< "$plan")
ca_bundle=$(jq -c '.caBundle' <<< "$plan")
set_secret "$receiver_ca" "$work_dir/ca.crt.json"
set_secret "$ca_bundle" "$work_dir/ca.pem.json"

for host in "${hosts[@]}"; do
    writer=$(jq -c --arg host "$host" '.writers[$host]' <<< "$plan")
    check_secret "$(jq -c '.clientCertificate' <<< "$writer")" "$work_dir/$host.crt"
    check_secret "$(jq -c '.clientKey' <<< "$writer")" "$work_dir/$host.key"
    check_secret "$(jq -c '.receiverCertificate' <<< "$writer")" "$work_dir/$host.crt"
done
check_secret "$receiver_ca" "$work_dir/ca.crt"
check_secret "$ca_bundle" "$work_dir/ca.pem"

printf '\nValidated supplied CA and generated %d client leaves. Staged encrypted updates for:\n' "${#hosts[@]}"
for file in "${secret_files[@]}"; do
    printf '  %s\n' "$file"
done
printf '\nNo live system changes yet. Type ROTATE to replace these encrypted files: '
read -r confirmation
[[ $confirmation == ROTATE ]] || die 'aborted without modifying repository files'

for file in "${secret_files[@]}"; do
    destination=$(telemetry_rotation_source "$repo_dir" "$file") ||
        die "$file source mapping changed while script ran; nothing published"
    cmp -s "$destination" "$work_dir/original/$file" ||
        die "$file changed while script ran; nothing published"
done

for file in "${secret_files[@]}"; do
    destination="${source_files[$file]}"
    temporary=$(mktemp "$destination.rotate.XXXXXX")
    cp --preserve=mode -- "$work_dir/staged/$file" "$temporary"
    mv -- "$temporary" "$destination"
done

printf '\nEncrypted SOPS files updated. Do not deploy until writer fingerprints for receiver %s are updated.\n' "$(jq -r '.receiver.host' <<< "$plan")"
printf 'Send only these fingerprints:\n\n'
for host in "${hosts[@]}"; do
    printf '%s %s\n' "$host" "${fingerprints[$host]}"
done
