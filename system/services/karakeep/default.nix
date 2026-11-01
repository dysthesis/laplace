{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.karakeep;
  inherit (lib) boolToString mkEnableOption mkIf;
in {
  options.laplace.services.karakeep =
    {enable = mkEnableOption "Karakeep, self-hosted bookmark-everything app";}
    // import ./settings.nix {inherit lib;};

  config = mkIf cfg.enable {
    # settings.env contains NEXTAUTH_SECRET. Meilisearch contains the index.
    # Persist the two directories to keep login sessions and prevent a new index build at each boot.
    mnemosyne.dirs = ["/var/lib/karakeep" "/var/lib/private/meilisearch"];

    # pnpm is a build-time dependency. An override of its insecure marker rebuilds Karakeep from source.
    # Remove this exception when nixpkgs uses pnpm 10.
    nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];

    services.karakeep = {
      enable = true;
      package = pkgs.unstable.karakeep;
      browser.port = cfg.browserPort;
      extraEnvironment = {
        # Next.js standalone defaults to 0.0.0.0, which permits connections outside the tailnet.
        HOSTNAME = cfg.listenAddress;
        PORT = toString cfg.port;
        NEXTAUTH_URL = "https://${cfg.domain}";
        DISABLE_SIGNUPS = boolToString cfg.disableSignups;
        # Nix owns the version.
        DISABLE_NEW_RELEASE_CHECK = "true";

        BROWSER_WEB_URL = "http://127.0.0.1:${toString cfg.browserPort}";
        HTML_CONTENT_SIZE_INLINE_THRESHOLD_BYTES = "65536";
      };
    };
    services.meilisearch.listenPort = cfg.searchPort;

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
