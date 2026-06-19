{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.services.adguardhome.enable;
in {
  options.laplace.services.adguardhome.enable =
    mkEnableOption "Whether or not to enable AdGuard Home";

  config = mkIf cfg {
    # AdGuard's config is managed through the web UI (filters, per-client rules,
    # rewrites). Persist its state dir so impermanence doesn't wipe it - including
    # the admin user created by the first-run wizard.
    #
    # The upstream module runs the unit with DynamicUser=true + StateDirectory,
    # so the real data lives at /var/lib/private/AdGuardHome and /var/lib/AdGuardHome
    # is just a symlink to it. Persist the private path: bind-mounting the public
    # path instead makes it a mountpoint, and systemd's DynamicUser migration then
    # rename()s it into /var/lib/private and dies with EBUSY ("Device or resource
    # busy", STATE_DIRECTORY exit 238).
    mnemosyne.dirs = ["/var/lib/private/AdGuardHome"];

    services.adguardhome = {
      enable = true;
      # Keep web-UI changes between rebuilds; no declarative settings to merge over.
      mutableSettings = true;
      # Don't open the web UI (3000/tcp) on every interface. AdGuard still binds
      # 0.0.0.0, but with the port closed in the host firewall only the tailnet
      # can reach the UI (tailscale0 is a trusted interface); the LAN cannot.
      openFirewall = false;
    };

    # The resolver port is opened explicitly so LAN/tailnet clients reach DNS on
    # 53; the web UI is deliberately not opened here (tailnet-only, see above).
    networking.firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
