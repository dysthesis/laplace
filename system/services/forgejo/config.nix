{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.forgejo;

  # Static Iosevka Medium and Bold faces use different font files.
  cadmus = inputs.iosevka-cadmus.packages.${pkgs.stdenv.hostPlatform.system}.iosevka-cadmus-nerd-font;
  # WOFF2 reduces font download size.
  cadmusWoff2 = pkgs.runCommand "iosevka-cadmus-woff2" {nativeBuildInputs = [pkgs.woff2];} ''
    mkdir -p "$out"
    for w in Medium MediumItalic Bold BoldItalic; do
      cp ${cadmus}/share/fonts/truetype/IosevkaCadmusNerdFont-$w.ttf "$out/"
      woff2_compress "$out/IosevkaCadmusNerdFont-$w.ttf"
      rm "$out/IosevkaCadmusNerdFont-$w.ttf"
    done
  '';

  # Harden oneshot services but keep /var and /run writable.
  hardenOneshot = {
    ProtectSystem = "full";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
  };
in {
  config = let
    inherit (config.services) forgejo;
    srv = forgejo.settings.server;
  in
    # The deployment recipe supplies the frontend identity and scoped LAN ingress.
    mkIf cfg.enable {
      mnemosyne.dirs = [
        forgejo.stateDir
        config.services.postgresql.dataDir
      ];

      systemd = {
        tmpfiles.rules = [
          "d '${forgejo.stateDir}' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/.ssh' 0700 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/custom' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/data' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/data/tmp' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/log' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/repositories' 0750 ${forgejo.user} ${forgejo.group} - -"
          "Z '${forgejo.stateDir}/.ssh' - ${forgejo.user} ${forgejo.group} - -"
          "Z '${forgejo.stateDir}/custom' - ${forgejo.user} ${forgejo.group} - -"
          "Z '${forgejo.stateDir}/dump' - ${forgejo.user} ${forgejo.group} - -"
          "Z '${forgejo.stateDir}/data' - ${forgejo.user} ${forgejo.group} - -"
          "Z '${forgejo.stateDir}/log' - ${forgejo.user} ${forgejo.group} - -"
          "Z '${forgejo.stateDir}/repositories' - ${forgejo.user} ${forgejo.group} - -"

          "d '${forgejo.stateDir}/custom/public' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/custom/public/assets' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/custom/public/assets/css' 0750 ${forgejo.user} ${forgejo.group} - -"
          "d '${forgejo.stateDir}/custom/public/assets/fonts' 0750 ${forgejo.user} ${forgejo.group} - -"
          "L+ '${forgejo.stateDir}/custom/public/assets/css/theme-minimal.css' - - - - ${./theme-minimal.css}"
          "L+ '${forgejo.stateDir}/custom/public/assets/fonts/IosevkaCadmusNerdFont-Medium.woff2' - - - - ${cadmusWoff2}/IosevkaCadmusNerdFont-Medium.woff2"
          "L+ '${forgejo.stateDir}/custom/public/assets/fonts/IosevkaCadmusNerdFont-MediumItalic.woff2' - - - - ${cadmusWoff2}/IosevkaCadmusNerdFont-MediumItalic.woff2"
          "L+ '${forgejo.stateDir}/custom/public/assets/fonts/IosevkaCadmusNerdFont-Bold.woff2' - - - - ${cadmusWoff2}/IosevkaCadmusNerdFont-Bold.woff2"
          "L+ '${forgejo.stateDir}/custom/public/assets/fonts/IosevkaCadmusNerdFont-BoldItalic.woff2' - - - - ${cadmusWoff2}/IosevkaCadmusNerdFont-BoldItalic.woff2"
          "L+ '${forgejo.stateDir}/custom/public/assets/fonts/AtkinsonHyperlegibleNext-var.ttf' - - - - ${pkgs.atkinson-hyperlegible-next}/share/fonts/truetype/AtkinsonHyperlegibleNext[wght].ttf"
          "L+ '${forgejo.stateDir}/custom/public/assets/fonts/AtkinsonHyperlegibleNext-Italic-var.ttf' - - - - ${pkgs.atkinson-hyperlegible-next}/share/fonts/truetype/AtkinsonHyperlegibleNext-Italic[wght].ttf"
        ];

        services.forgejo-secrets.serviceConfig = hardenOneshot;
        services.forgejo-dump.serviceConfig =
          mkIf forgejo.dump.enable hardenOneshot;
      };

      services = {
        forgejo = {
          enable = true;
          # Use Forgejo 16 or later for Zoekt.
          package = pkgs.forgejo;
          inherit (cfg) stateDir;
          user = "git";
          group = "git";
          database = {
            type = "postgres";
            user = "git";
            name = "git";
          };
          lfs.enable = true;

          # Weekly logical dumps help restores across major versions. VM backups are the primary recovery method.
          # Use pgBackRest if the recovery point must be less than one week.
          dump = {
            enable = true;
            type = "tar.zst";
            interval = "weekly";
            age = "14d";
          };

          settings = {
            repository = {
              USE_COMPAT_SSH_URI = false;
              DEFAULT_PRIVATE = "private";
            };
            DEFAULT.APP_NAME = "Hephaestus";

            # Zoekt shards share the guest disk.
            # Limit repositories or move shards if disk space becomes insufficient.
            indexer = {
              REPO_INDEXER_ENABLED = true;
              REPO_INDEXER_TYPE = "zoekt";
            };

            server = {
              DOMAIN = cfg.domain;
              ROOT_URL = "https://${srv.DOMAIN}/";
              LANDING_PAGE = "explore";
              HTTP_ADDR = cfg.listenAddress;
              HTTP_PORT = cfg.port;
              SSH_USER = "git";
              SSH_PORT = lib.head config.services.openssh.ports;
            };

            service = {
              DISABLE_REGISTRATION = true;
              # Hide the administrator email address in commit author and API views.
              DEFAULT_KEEP_EMAIL_PRIVATE = true;
            };

            # Anubis flattens the proxy chain, so Forgejo sees one trusted hop.
            security = {
              REVERSE_PROXY_TRUSTED_PROXIES = lib.concatStringsSep "," cfg.trustedProxies;
              # PASSWORD_COMPLEXITY must be a comma-separated string.
              MIN_PASSWORD_LENGTH = 12;
              PASSWORD_COMPLEXITY = "lower,upper,digit,spec";
              PASSWORD_HASH_ALGO = "argon2"; # The memory-hard algorithm applies when users set passwords.
              LOGIN_REMEMBER_DAYS = 7;
              # URL query tokens leak through logs and Referer headers.
              DISABLE_QUERY_AUTH_TOKEN = true;
              GLOBAL_TWO_FACTOR_REQUIREMENT = "admin";
            };

            # The module overrides Forgejo's HTTPS detection, so force secure cookies.
            session.COOKIE_SECURE = true;

            ui = {
              DEFAULT_THEME = "minimal";
              THEMES = "minimal";
            };

            other.SHOW_FOOTER_VERSION = false;

            actions = {
              ENABLED = true;
              DEFAULT_ACTIONS_URL = "github";
            };
          };
        };
      };

      users = {
        users.git = {
          home = config.services.forgejo.stateDir;
          useDefaultShell = true;
          group = "git";
          isSystemUser = true;
        };

        groups.git = {};
      };
    };
}
