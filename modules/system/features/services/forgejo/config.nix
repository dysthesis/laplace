{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkAfter mkIf;
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

    installPhase = ''
      mkdir -p $out
      cp $src/* $out
      chmod -R +w $out
      find $out -name '*.css' -exec sed -i 's/#1e1e2e/#000000/g' {} +
      find $out -name '*.css' -exec sed -i 's/#cdd6f4/#ffffff/g' {} +
      find $out -name '*.css' -exec sed -i 's/#313244/#1e1e2e/g' {} +
      find $out -name '*.css' -exec sed -i 's/#45475a/#313244/g' {} +
      find $out -name '*.css' -exec sed -i 's/#585b70/#45475a/g' {} +
      chmod -R -w $out
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
    services.forgejo = let
      srv = config.services.forgejo.settings.server;
    in {
      enable = true;
      database.type = "postgres";
      # Enable support for Git Large File Storage
      lfs.enable = true;
      settings = {
        federation.ENABLED = true;

        server = {
          DOMAIN = "git.dysthesis.com";
          # You need to specify this to remove the port from URLs in the web UI.
          ROOT_URL = "https://${srv.DOMAIN}/";
          HTTP_PORT = 3000;
        };

        ui = {
          DEFAULT_THEME = "catppuccin-mocha-blue";
          THEMES = builtins.concatStringsSep "," (
            ["auto,forgejo-auto,forgejo-dark,forgejo-light,arc-gree,gitea"]
            ++ (map (name: removePrefix "theme-" (removeSuffix ".css" name)) (
              builtins.attrNames (builtins.readDir oledppuccin-theme)
            ))
          );
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
        # Add support for actions, based on act: https://github.com/nektos/act
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
      };
    };
  };
}
