{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.caddy.enable;
in {
  config = mkIf cfg {
    services.caddy = {
      enable = true;
      config = ''
        :8080 {
          root * ${inputs.episteme.packages.${pkgs.system}.default}/share
          try_files {path} {path}.html {path}/ =404
          encode gzip
          file_server
          handle_errors {
            rewrite * /{err.status_code}.html
            file_server
          }
        }
      '';
    };
  };
}
