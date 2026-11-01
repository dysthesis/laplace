{
  pkgs,
  lib,
  inputs,
  self,
  serviceFixtures,
}: {
  # configtest must have writable state in $TMPDIR.
  headscale-policy = let
    headscalePackage = serviceFixtures.headscale.services.headscale.package;
    emptyFixtures = import ./service-fixtures.nix {
      inherit lib inputs self;
      extraModules = [
        {
          laplace.tailnet.nodeFlows = lib.mkForce [];
          laplace.tailnet.serviceGrants = lib.mkForce [];
        }
      ];
    };
    emptyPolicy = emptyFixtures.headscale.laplace.services.headscale.acl.policyFile;
  in
    pkgs.runCommand "headscale-policy-check"
    {
      nativeBuildInputs = [headscalePackage pkgs.jq];
    } ''
      config="$TMPDIR/headscale.yaml"
      cp ${serviceFixtures.headscale.services.headscale.configFile} "$config"
      substituteInPlace "$config" \
        --replace-fail /var/lib/headscale "$TMPDIR/state" \
        --replace-fail /run/headscale "$TMPDIR/run"
      mkdir -p "$TMPDIR/state" "$TMPDIR/run"

      headscale --force configtest --config "$config"
      headscale --force policy check \
        --bypass-grpc-and-access-database-directly \
        --config "$config" \
        --file ${serviceFixtures.headscale.laplace.services.headscale.acl.policyFile}
      jq -e '.acls == []' ${emptyPolicy}
      headscale --force policy check \
        --bypass-grpc-and-access-database-directly \
        --config "$config" --file ${emptyPolicy}
      touch $out
    '';

  tailnet-reconcile = pkgs.runCommand "tailnet-reconcile-check" {nativeBuildInputs = [pkgs.jq];} ''
    ssot='{
      "alpha":{"ip":"100.64.0.1","ip6":"fd7a:115c:a1e0::1","tags":["infra","monitor"]},
      "beta":{"ip":"100.64.0.2","ip6":"fd7a:115c:a1e0::2","tags":["infra"]}
    }'
    problems=$(jq -r --argjson ssot "$ssot" -f ${../../system/tailnet/reconcile.jq} <<'JSON'
    [
      {
        "name":"wrong-name",
        "given_name":"alpha",
        "ip_addresses":["100.64.0.9","fd7a:115c:a1e0::9"],
        "tags":["tag:infra"]
      },
      {
        "name":"gamma",
        "given_name":"gamma",
        "ip_addresses":["100.64.0.3","fd7a:115c:a1e0::3"],
        "tags":["tag:game"]
      },
      {
        "name":"guest",
        "given_name":"guest",
        "ip_addresses":["100.64.0.4","fd7a:115c:a1e0::4"],
        "tags":[]
      },
      {
        "name":"guest-copy",
        "given_name":"guest",
        "ip_addresses":["100.64.0.5","fd7a:115c:a1e0::5"],
        "tags":[]
      }
    ]
    JSON
    )
    jq -e '
      sort_by(.kind) == ([
        {kind:"tag-drift", node:"alpha", expected:["infra","monitor"], actual:["infra"]},
        {kind:"address-drift", node:"alpha",
          expected:["100.64.0.1","fd7a:115c:a1e0::1"],
          actual:["100.64.0.9","fd7a:115c:a1e0::9"]},
        {kind:"missing", node:"beta"},
        {kind:"unexpected", node:"gamma"},
        {kind:"duplicate", node:"guest"}
      ] | sort_by(.kind))
    ' <<< "$problems"
    printf '%s' '[{"given_name":"alpha","ip_addresses":["100.64.0.1","fd7a:115c:a1e0::1"],"tags":["tag:monitor","tag:infra"]}]' \
      | jq --argjson ssot '{"alpha":{"ip":"100.64.0.1","ip6":"fd7a:115c:a1e0::1","tags":["infra","monitor"]}}' \
        -f ${../../system/tailnet/reconcile.jq} | jq -e '. == []'
    touch $out
  '';
}
