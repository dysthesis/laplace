# Single source of truth for tailnet node identity — the "frontend" the §5
# topology audit (PLAN.md) describes. For now it carries each node's stable
# Headscale-assigned IPv4; consumers (the headscale ACL hosts/extra_records on
# bifrost today, per-node nftables + fail2ban later) read this instead of
# repeating the addresses.
#
# Pure data, identical on every host: a node cannot read a peer's `config` at
# eval, so this must NOT be derived from cross-node config — it is a plain
# constant imported fleet-wide (via system/ -> importInDirectory), and each
# consumer filters by `config.networking.hostName`.
#
# Tags, IPv6 (the tailnet ULA fd7a:115c:a1e0::/48 is live — see PLAN §5a gotcha
# 1) and the reachability matrix land in later changes; this module is the
# addressing dedup only.
{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.laplace.tailnet.nodes = mkOption {
    type = types.attrsOf (types.submodule {
      options.ip = mkOption {
        type = types.str;
        description = "Stable Headscale-assigned tailnet IPv4 (bare address, no prefix).";
      };
    });
    default = {};
    description = ''
      Tailnet nodes keyed by hostname, each `{ ip }`. The sole source of truth for
      tailnet addressing. Confirmed against `headscale nodes list`.
    '';
  };

  config.laplace.tailnet.nodes = {
    hermes = {ip = "100.64.0.5";}; # AdGuard = tailnet resolver
    mneme = {ip = "100.64.0.6";}; # Immich
    mimir = {ip = "100.64.0.8";}; # miniflux/silverbullet/vikunja + beszel-hub
    loki = {ip = "100.64.0.12";}; # Minecraft
    charon = {ip = "100.64.0.3";}; # exit node
    phobos = {ip = "100.64.0.1";}; # workstation (laptop)
    deimos = {ip = "100.64.0.4";}; # workstation (PC)
    phone = {ip = "100.64.0.2";}; # tag:phone (current mobile)
    device = {ip = "100.64.0.7";}; # tag:phone (old phone)
  };
}
