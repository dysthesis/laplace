{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.laplace.features.services.searxng.enable;
  inherit (lib) mkIf;
  port = 8100;
in {
  config = mkIf cfg {
    networking.firewall.allowedTCPPorts = [port];
    services.searx = {
      package = pkgs.searxng;
      enable = true;
      runInUwsgi = false;
      limiterSettings = {
        botdetection = {
          ip_lists = {
            pass_ip = [
              "192.168.0.0/16"
              "172.16.0.0/12"
              "10.0.0.0/8"
            ];
          };
        };
      };
      settings = {
        general = {
          debug = false;
          instance_name = "Galileo";
        };
        ui = {
          default_theme = "simple";
          theme_args = {
            simple_style = "dark";
          };
        };
        search = {
          autocomplete = "google";
          safe_search = 0;
          default_lang = "en-AU";
        };
        server = {
          inherit port;
          bind_address = "0.0.0.0";
          public_instance = false;
          infinite_scroll = true;
        };
      };
    };
  };
}
