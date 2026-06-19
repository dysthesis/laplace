{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [./config.nix];

  options.laplace.services.linkwarden = {
    enable = mkEnableOption "Linkwarden self-hosted bookmark manager";

    # Upstream disables registration by default, which locks out the very first
    # signup. Turn this on once to create the initial account, then turn it off.
    enableRegistration = mkEnableOption "new-user registration in the web UI";

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = ''
        Address Linkwarden binds to. Defaults to 0.0.0.0 so it is reachable over
        the tailnet; the host firewall trusts only tailscale0
        (laplace.services.tailscale) and the Linkwarden port is never opened, so
        this stays tailnet-only and is not exposed on the LAN or publicly.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port Linkwarden listens on.";
    };
  };
}
