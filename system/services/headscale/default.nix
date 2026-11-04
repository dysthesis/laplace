{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.laplace.services.headscale;
in {
  imports = [
    ./acl.nix
    ./wg-only.nix
  ];

  options.laplace.services.headscale = {
    enable = mkEnableOption "Headscale coordination server";

    fqdn = mkOption {
      type = types.str;
      default = "headscale.dysthesis.com";
      description = "Public hostname clients use to reach Headscale.";
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address Headscale listens on.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port Headscale listens on.";
    };

    baseDomain = mkOption {
      type = types.str;
      default = "tailnet.dysthesis.com";
      description = "MagicDNS base domain for Headscale nodes.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Headscale listen port in the host firewall.";
    };
  };

  config = mkIf cfg.enable {
    mnemosyne.dirs = [
      "/var/lib/private/headscale"
      "/var/lib/headscale"
    ];

    services.headscale = {
      enable = true;
      inherit (cfg) address port;

      settings = {
        server_url = "https://${cfg.fqdn}";
        dns = {
          base_domain = cfg.baseDomain;
          # Use split DNS by default. Hosts can select a tailnet nameserver instead.
          # Bifrost routes tailnet DNS through AdGuard.
          override_local_dns = lib.mkDefault false;
        };
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };
}
