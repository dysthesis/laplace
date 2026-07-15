#!/usr/bin/env bash
set -euo pipefail

readonly hosts=(talos mneme mimir horos hermes charon loki hephaestus bifrost portunus)
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_dir
readonly secrets_dir="$repo_dir/system/secrets"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

for command in cmp jq mktemp openssl sops; do
    command -v "$command" >/dev/null ||
        die "missing $command; run with: nix shell nixpkgs#jq nixpkgs#openssl nixpkgs#sops -c $0"
done

[[ $# -eq 2 ]] || die "usage: $0 <new-ca-certificate.pem> <new-ca-private-key.pem>"
readonly ca_certificate_input=$1
readonly ca_key_input=$2
[[ -r $ca_certificate_input ]] || die "cannot read CA certificate: $ca_certificate_input"
[[ -r $ca_key_input ]] || die "cannot read CA private key: $ca_key_input"

[[ -w /dev/shm ]] || die '/dev/shm must be writable; plaintext keys must stay on tmpfs'
[[ -r "$secrets_dir/telemetry-ca.yaml" ]] || die 'missing system/secrets/telemetry-ca.yaml'
[[ -r "$secrets_dir/argus.yaml" ]] || die 'missing system/secrets/argus.yaml'
for host in "${hosts[@]}"; do
    [[ -r "$secrets_dir/$host.yaml" ]] || die "missing system/secrets/$host.yaml"
done

umask 077
work_dir=$(mktemp -d /dev/shm/laplace-telemetry-ca.XXXXXX)
trap 'rm -rf -- "$work_dir"' EXIT HUP INT TERM
mkdir "$work_dir/original" "$work_dir/staged"

secret_files=(telemetry-ca.yaml argus.yaml)
for host in "${hosts[@]}"; do
    secret_files+=("$host.yaml")
done
for file in "${secret_files[@]}"; do
    cp -- "$secrets_dir/$file" "$work_dir/original/$file"
    cp -- "$secrets_dir/$file" "$work_dir/staged/$file"
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

    host_sops_file="$work_dir/staged/$host.yaml"
    sops set --value-file "$host_sops_file" '["telemetry_client_certificate"]' "$certificate.json"
    sops set --value-file "$host_sops_file" '["telemetry_client_key"]' "$key.json"
    sops set --value-file \
        "$work_dir/staged/argus.yaml" \
        "[\"telemetry_${host}_client_certificate\"]" \
        "$certificate.json"
done

jq -Rs . <"$work_dir/ca.crt" >"$work_dir/ca.crt.json"
jq -Rs . <"$work_dir/ca.pem" >"$work_dir/ca.pem.json"
sops set --value-file \
    "$work_dir/staged/argus.yaml" \
    '["telemetry_ingress_client_ca"]' \
    "$work_dir/ca.crt.json"
sops set --value-file \
    "$work_dir/staged/telemetry-ca.yaml" \
    '["data"]' \
    "$work_dir/ca.pem.json"

for host in "${hosts[@]}"; do
    cmp -s \
        <(sops --decrypt --extract '["telemetry_client_certificate"]' "$work_dir/staged/$host.yaml") \
        "$work_dir/$host.crt" ||
        die "$host certificate failed staged SOPS validation"
    cmp -s \
        <(sops --decrypt --extract '["telemetry_client_key"]' "$work_dir/staged/$host.yaml") \
        "$work_dir/$host.key" ||
        die "$host private key failed staged SOPS validation"
    cmp -s \
        <(sops --decrypt --extract "[\"telemetry_${host}_client_certificate\"]" "$work_dir/staged/argus.yaml") \
        "$work_dir/$host.crt" ||
        die "$host Argus certificate failed staged SOPS validation"
done
cmp -s \
    <(sops --decrypt --extract '["telemetry_ingress_client_ca"]' "$work_dir/staged/argus.yaml") \
    "$work_dir/ca.crt" ||
    die 'Argus CA certificate failed staged SOPS validation'
cmp -s \
    <(sops --decrypt --extract '["data"]' "$work_dir/staged/telemetry-ca.yaml") \
    "$work_dir/ca.pem" ||
    die 'CA bundle failed staged SOPS validation'

printf '\nValidated supplied CA and generated ten client leaves. Staged encrypted updates for:\n'
for file in "${secret_files[@]}"; do
    printf '  system/secrets/%s\n' "$file"
done
printf '\nNo live system changes yet. Type ROTATE to replace these encrypted files: '
read -r confirmation
[[ $confirmation == ROTATE ]] || die 'aborted without modifying repository files'

for file in "${secret_files[@]}"; do
    cmp -s "$secrets_dir/$file" "$work_dir/original/$file" ||
        die "system/secrets/$file changed while script ran; nothing published"
done

for file in "${secret_files[@]}"; do
    destination="$secrets_dir/$file"
    temporary=$(mktemp "$destination.rotate.XXXXXX")
    cp --preserve=mode -- "$work_dir/staged/$file" "$temporary"
    mv -- "$temporary" "$destination"
done

printf '\nEncrypted SOPS files updated. Do not deploy until Argus fingerprints are updated.\n'
printf 'Send only these fingerprints:\n\n'
for host in "${hosts[@]}"; do
    printf '%s %s\n' "$host" "${fingerprints[$host]}"
done
