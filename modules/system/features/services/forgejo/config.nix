{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkAfter mkForce mkIf;
  inherit (lib.strings) removePrefix removeSuffix;

  cfg = config.laplace.features.services.forgejo.enable;

  oledppuccin-theme = pkgs.stdenv.mkDerivation rec {
    pname = "oledppuccin-gitea";
    version = "v0.4.1";
    src = pkgs.fetchzip {
      url = "https://github.com/catppuccin/gitea/releases/download/${version}/catppuccin-gitea.tar.gz";
      hash = "sha256-14XqO1ZhhPS7VDBSzqW55kh6n5cFZGZmvRCtMEh8JPI=";
      stripRoot = false;
    };

    patchPhase = ''
      find . -name '*.css' -exec sed -i 's/#1e1e2e/#000000/g' {} +
      find . -name '*.css' -exec sed -i 's/#cdd6f4/#ffffff/g' {} +
      find . -name '*.css' -exec sed -i 's/#313244/#1e1e2e/g' {} +
      find . -name '*.css' -exec sed -i 's/#45475a/#313244/g' {} +
      find . -name '*.css' -exec sed -i 's/#585b70/#45475a/g' {} +
    '';

    installPhase = ''
      mkdir -p $out
      cp $src/* $out
    '';
  };
in {
  config = mkIf cfg {
    systemd.services = {
      forgejo = {
        preStart = let
          inherit (config.services.forgejo) stateDir;
        in
          mkAfter ''
            rm -rf ${stateDir}/custom/public/assets
            mkdir -p ${stateDir}/custom/public/assets
            ln -sf ${oledppuccin-theme} ${stateDir}/custom/public/assets/css
          '';
      };
    };
    services.forgejo = {
      enable = true;
      package = pkgs.unstable.forgejo;

      stateDir = "/var/lib/forgejo";

      lfs.enable = true;

      settings = {
        federation.ENABLED = true;

        server = {
          PROTOCOL = "http+unix";
          ROOT_URL = "https://git.dysthesis.com";
          HTTP_PORT = 7000;
          DOMAIN = "git.dysthesis.com";

          BUILTIN_SSH_SERVER_USER = "git";
          DISABLE_ROUTER_LOG = true;
          LANDING_PAGE = "/explore/repos";

          START_SSH_SERVER = true;
          SSH_CREATE_AUTHORIZED_KEYS_FILE = true;
          SSH_PORT = 2222;
          SSH_LISTEN_PORT = 2222;
        };

        DEFAULT.APP_NAME = "hephaestus";

        ui = {
          DEFAULT_THEME = "catppuccin-mocha-blue";
          THEMES = builtins.concatStringsSep "," (
            ["auto,forgejo-auto,forgejo-dark,forgejo-light,arc-gree,gitea"]
            ++ (map (name: removePrefix "theme-" (removeSuffix ".css" name)) (
              builtins.attrNames (builtins.readDir oledppuccin-theme)
            ))
          );
        };
        atabase = {
          DB_TYPE = mkForce "postgres";
          HOST = "/run/postgresql";
          NAME = "forgejo";
          USER = "forgejo";
          PASSWD = "forgejo";
        };

        # cache = {
        #   ENABLED = true;
        #   ADAPTER = "redis";
        #   HOST = "redis://:forgejo@localhost:6371";
        # };

        oauth2_client = {
          ACCOUNT_LINKING = "login";
          USERNAME = "nickname";
          ENABLE_AUTO_REGISTRATION = false;
          REGISTER_EMAIL_CONFIRM = false;
          UPDATE_AVATAR = true;
        };

        service = {
          DISABLE_REGISTRATION = false;
          ALLOW_ONLY_INTERNAL_REGISTRATION = true;
          EMAIL_DOMAIN_ALLOWLIST = "dysthesis.com";
          ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
        };

        session = {
          COOKIE_SECURE = true;
          # Sessions last for 1 week
          SESSION_LIFE_TIME = 86400 * 7;
        };

        other = {
          SHOW_FOOTER_VERSION = false;
          SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
          ENABLE_FEED = false;
        };

        migrations.ALLOWED_DOMAINS = "github.com, *.github.com, gitlab.com, *.gitlab.com";
        packages.ENABLED = false;
        repository.PREFERRED_LICENSES = "MIT,GPL-3.0,GPL-2.0,LGPL-3.0,LGPL-2.1";

        "repository.upload" = {
          FILE_MAX_SIZE = 100;
          MAX_FILES = 10;
        };
      };
    };
  };
}
