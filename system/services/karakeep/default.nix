{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.karakeep;
  inherit (lib) boolToString mkEnableOption mkIf mkOption types;
in {
  options.laplace.services.karakeep = {
    enable = mkEnableOption "Karakeep, self-hosted bookmark-everything app";

    domain = mkOption {
      type = types.str;
      example = "read.example.com";
      description = "Public origin (`NEXTAUTH_URL`). Node-local Caddy terminates TLS and proxies {option}`port`.";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Loopback HTTP port the web app listens on.";
    };

    disableSignups = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Reject new registrations. Leave false until the first account exists —
        it becomes the admin — then flip it.
      '';
    };
  };

  config = mkIf cfg.enable {
    # settings.env holds the generated NEXTAUTH_SECRET, meilisearch holds the
    # index; both must outlive the tmpfs root or each boot logs everyone out
    # and reindexes.
    mnemosyne.dirs = ["/var/lib/karakeep" "/var/lib/private/meilisearch"];

    # Build-time dep only. Overriding the marking instead rebuilds karakeep
    # from source; drop when nixpkgs moves it to pnpm 10.
    nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];

    services.karakeep = {
      enable = true;
      package = pkgs.unstable.karakeep;
      extraEnvironment = {
        # Next.js standalone defaults to 0.0.0.0, which escapes the tailnet.
        HOSTNAME = "127.0.0.1";
        PORT = toString cfg.port;
        NEXTAUTH_URL = "https://${cfg.domain}";
        DISABLE_SIGNUPS = boolToString cfg.disableSignups;
        # Nix owns the version.
        DISABLE_NEW_RELEASE_CHECK = "true";

        BROWSER_WEB_URL = "http://127.0.0.1:9222";
        HTML_CONTENT_SIZE_INLINE_THRESHOLD_BYTES = "65536";
      };
    };

    systemd.services = {
      karakeep-web.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };
      karakeep-workers.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };
}
