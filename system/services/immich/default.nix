{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [./config.nix];

  options.laplace.services.immich = {
    enable = mkEnableOption "Immich self-hosted photo and video backup";

    mediaLocation = mkOption {
      type = types.path;
      default = "/var/lib/immich";
      description = "Directory where Immich stores uploaded media.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = ''
        Address Immich binds to. Defaults to 0.0.0.0 so it is reachable over the
        tailnet; the host firewall trusts only tailscale0
        (laplace.services.tailscale), and the Immich port is never opened, so
        this stays tailnet-only and is not exposed on the LAN or publicly.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 2283;
      description = "Port Immich listens on.";
    };
  };
}
