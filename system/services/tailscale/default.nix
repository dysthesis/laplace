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

      # The Tailscale module enables resolved by default.
      # Its 127.0.0.53 stub occupies port 53.
      resolved.enable = mkIf cfg.denyDNS (mkForce false);
    };

    warnings = optional (length operatorCandidates > 1) "Tailscale supports one --operator user; using demiurge because both demiurge and archon are enabled.";

    networking = {
      nftables.enable = true;
      firewall = {
        enable = true;
        trustedInterfaces = [config.services.tailscale.interfaceName];
        allowedUDPPorts = [config.services.tailscale.port];
        # Strict reverse-path filtering rejects Tailscale asymmetric and forwarded traffic.
        # Use loose mode. mkDefault lets each host select its own policy.
        checkReversePath = lib.mkDefault "loose";
      };
    };

    # Exit nodes must forward IP traffic for --advertise-exit-node routes.
    boot.kernel.sysctl = mkIf cfg.advertiseExitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Use nftables because automatic detection can select iptables-compat.
    # The iptables-compat backend does not work on nftables-only hosts.
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    # tailscaled starts the tunnel itself. A network-online wait delays boot.
    systemd.network.wait-online.enable = false;
    boot.initrd.systemd.network.wait-online.enable = false;
  };
}
