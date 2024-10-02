{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkAfter mkForce mkIf;
  inherit (lib.strings) removePrefix removeSuffix;

  cfg = config.laplace.features.forgejo.enable;

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
    services.forgejo = let
      srv = config.services.forgejo.settings.server;
    in {
      enable = true;
      database.type = "postgres";
      # Enable support for Git Large File Storage
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = "git.dysthesis.com";
          # You need to specify this to remove the port from URLs in the web UI.
          ROOT_URL = "https://${srv.DOMAIN}/";
          HTTP_PORT = 3000;
        };
        # You can temporarily allow registration to create an admin user.
        service.DISABLE_REGISTRATION = true;
        # Add support for actions, based on act: https://github.com/nektos/act
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
      };
    };
  };
}
