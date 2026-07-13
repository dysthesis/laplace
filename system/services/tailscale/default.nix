{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkForce optional optionals;
  inherit (builtins) elem filter head length;
  cfg = config.laplace.services.tailscale;
  operatorCandidates = filter (user: elem user config.laplace.users) ["demiurge" "archon"];
  operatorUser =
    if operatorCandidates == []
    then null
    else head operatorCandidates;
in {
  options.laplace.services.tailscale = {
    enable = mkEnableOption "Whether or not to enable Tailscale";
    advertiseExitNode = mkEnableOption "advertising this host as a Tailscale exit node (adds --advertise-exit-node and enables IPv4/IPv6 forwarding, both required to route peer traffic; the 0.0.0.0/0 + ::/0 routes still need approval on the control server, e.g. headscale autoApprovers.exitNode)";
    denySubnetRoutes = mkEnableOption "refusing subnet routes advertised by tailnet peers (sets --accept-routes=false), so a peer advertising the local LAN can't blackhole it through the tunnel";
    denyDNS = mkEnableOption "refusing the tailnet's DNS settings (sets --accept-dns=false and disables the systemd-resolved unit the tailscale module enables by default), so resolved's loopback :53 stubs don't squat tcp/53 - leaving the port free for a local resolver like AdGuard";
  };
  config = mkIf cfg.enable {
    mnemosyne.dirs = ["/var/lib/tailscale"];

    services = {
      tailscale = {
        enable = true;
        disableUpstreamLogging = true;
        extraSetFlags =
          optionals cfg.advertiseExitNode ["--advertise-exit-node"]
          ++ optionals cfg.denySubnetRoutes ["--accept-routes=false"]
          ++ optionals cfg.denyDNS ["--accept-dns=false"]
          ++ optionals (operatorUser != null) ["--operator=${operatorUser}"];
      };

      # mkForce: the upstream tailscale module mkDefault-enables resolved, whose
      # 127.0.0.53 stub would squat :53 (see the denyDNS option description).
      resolved.enable = mkIf cfg.denyDNS (mkForce false);
    };

    warnings = optional (length operatorCandidates > 1) "Tailscale supports one --operator user; using demiurge because both demiurge and archon are enabled.";

    networking = {
      nftables.enable = true;
      firewall = {
        enable = true;
        trustedInterfaces = [config.services.tailscale.interfaceName];
        allowedUDPPorts = [config.services.tailscale.port];
        # Tailscale's asymmetric routing (and subnet-router/exit-node forwarding)
        # is dropped by strict reverse-path filtering, so relax it to "loose" on
        # tailnet hosts. mkDefault lets a host override per its needs.
        checkReversePath = lib.mkDefault "loose";
      };
    };

    # An exit node must forward IP, or the kernel drops the very traffic the
    # --advertise-exit-node flag advertises a route for. Bundled into the option
    # so enabling it is sufficient on its own.
    boot.kernel.sysctl = mkIf cfg.advertiseExitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Pin tailscaled's firewall backend to nftables; autodetect can fall back to
    # the iptables-compat shim, which misbehaves on nftables-only hosts.
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    # Don't block boot waiting for network-online: tailscaled brings the tunnel
    # up itself, so the wait only stalls startup.
    systemd.network.wait-online.enable = false;
    boot.initrd.systemd.network.wait-online.enable = false;
  };
}
