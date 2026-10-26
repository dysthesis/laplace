{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [./config.nix];

  options.laplace.services.forgejo = {
    enable = mkEnableOption "Whether or not to enable Forgejo";
    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/forgejo";
      description = "Where Forgejo stores state data";
    };
    domain = mkOption {
      type = types.str;
      default = "git.dysthesis.com";
      description = "Public Forgejo frontend hostname.";
    };
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Forgejo HTTP bind address.";
    };
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Forgejo HTTP backend port.";
    };
    trustedProxies = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Trusted HTTP reverse proxy source networks.";
    };
  };
}
