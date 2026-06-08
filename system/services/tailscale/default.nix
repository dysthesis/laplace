{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.services.tailscale;
in {
  options.laplace.services.tailscale = {
    enable = mkEnableOption "Whether or not to enable Tailscale";
    denySubnetRoutes = mkEnableOption "refusing subnet routes advertised by tailnet peers (sets --accept-routes=false), so a peer advertising the local LAN can't blackhole it through the tunnel";
  };
  config = mkIf cfg.enable {
    mnemosyne.dirs = ["/var/lib/tailscale"];

    # Taken from https://wiki.nixos.org/wiki/Tailscale
    services.tailscale.enable = true;

    # Optionally refuse subnet routes advertised by tailnet peers. Without this, a
    # peer advertising the local LAN routes it through the tunnel and blackholes
    # LAN hosts (router, proxmox) when the advertiser drops.
    services.tailscale.extraSetFlags = mkIf cfg.denySubnetRoutes ["--accept-routes=false"];
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
