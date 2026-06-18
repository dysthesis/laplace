{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkForce optionals;
  cfg = config.laplace.services.tailscale;
in {
  options.laplace.services.tailscale = {
    enable = mkEnableOption "Whether or not to enable Tailscale";
    denySubnetRoutes = mkEnableOption "refusing subnet routes advertised by tailnet peers (sets --accept-routes=false), so a peer advertising the local LAN can't blackhole it through the tunnel";
    denyDNS = mkEnableOption "refusing the tailnet's DNS settings (sets --accept-dns=false and disables the systemd-resolved unit the tailscale module enables by default), so resolved's loopback :53 stubs don't squat tcp/53 - leaving the port free for a local resolver like AdGuard";
  };
  config = mkIf cfg.enable {
    mnemosyne.dirs = ["/var/lib/tailscale"];

    # Taken from https://wiki.nixos.org/wiki/Tailscale
    services.tailscale.enable = true;

    # Optionally refuse subnet routes advertised by tailnet peers. Without this, a
    # peer advertising the local LAN routes it through the tunnel and blackholes
    # LAN hosts (router, proxmox) when the advertiser drops.
    #
    # denyDNS keeps tailscaled out of the host's DNS. The runtime --accept-dns=false
    # alone is not enough: the upstream tailscale module enables systemd-resolved
    # (mkDefault true), whose 127.0.0.53/127.0.0.54 stubs hold tcp/53 and collide
    # with a local resolver binding 0.0.0.0:53 (e.g. AdGuard). So also tear down the
    # resolved unit; the host then resolves via networking.nameservers directly.
    services.tailscale.extraSetFlags =
      optionals cfg.denySubnetRoutes ["--accept-routes=false"]
      ++ optionals cfg.denyDNS ["--accept-dns=false"];
    services.resolved.enable = mkIf cfg.denyDNS (mkForce false);
    networking.nftables.enable = true;
    networking.firewall = {
      enable = true;
      # Always allow traffic from your Tailscale network
      trustedInterfaces = [config.services.tailscale.interfaceName];
      # Allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [config.services.tailscale.port];
    };

    # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
    # This avoids the "iptables-compat" translation layer issues.
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    # 3. Optimization: Prevent systemd from waiting for network online
    # (Optional but recommended for faster boot with VPNs)
    systemd.network.wait-online.enable = false;
    boot.initrd.systemd.network.wait-online.enable = false;
  };
}
